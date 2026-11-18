#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Put a custom recovery ramdisk (TWRP / OrangeFox / any) into the STOCK
# vendor_boot.img of the moto g73 5G.
#
# The g73 has no recovery partition: recovery lives as a ramdisk fragment
# inside vendor_boot (boot image header v4). Rebuilding vendor_boot from
# scratch risks breaking normal boot (it also carries the first-stage fstab,
# vendor modules and the DTB). This script keeps every stock fragment as-is
# and only replaces (or adds) the RECOVERY-type fragment.
#
# Usage:
#   repack-vendor-boot.sh -s stock_vendor_boot.img -r <recovery> -o out.img
#   repack-vendor-boot.sh -e OUT -r vendor_boot.img
#
#   <recovery> can be:
#     * a recovery ramdisk (.cpio, .cpio.lz4, .cpio.gz), or
#     * a vendor_boot.img produced by a TWRP build (its recovery fragment is used)
#
#   -e OUT only extracts the RECOVERY fragment (type 2) of the vendor_boot
#   given with -r into the file OUT (-s and -o are not needed in this mode).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="${TOOLS:-$ROOT/src/tools}"

STOCK="" RECOVERY="" OUTPUT="" EXTRACT=""
usage() {
    sed -n '/^# Usage:/,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'
}
while getopts "s:r:o:e:h" opt; do
    case "$opt" in
        s) STOCK="$(realpath "$OPTARG")" ;;
        r) RECOVERY="$(realpath "$OPTARG")" ;;
        o) OUTPUT="$(realpath -m "$OPTARG")" ;;
        e) EXTRACT="$(realpath -m "$OPTARG")" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
if [[ -n "$EXTRACT" ]]; then
    [[ -n "$RECOVERY" ]] || { usage; exit 1; }
else
    [[ -n "$STOCK" && -n "$RECOVERY" && -n "$OUTPUT" ]] || { usage; exit 1; }
    [[ -f "$STOCK" ]] || { echo "error: $STOCK not found" >&2; exit 1; }
fi
[[ -f "$RECOVERY" ]] || { echo "error: $RECOVERY not found" >&2; exit 1; }

"$ROOT/scripts/fetch-tools.sh" --quiet
MKBOOTIMG=(python3 "$TOOLS/mkbootimg/mkbootimg.py")
UNPACK=(python3 "$TOOLS/mkbootimg/unpack_bootimg.py")

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

is_vendor_boot() {
    [[ "$(head -c 8 "$1" | tr -d '\0')" == "VNDRBOOT" ]]
}

# Read the mkbootimg argument list (NUL separated) of a vendor_boot image.
read_args() {
    local img="$1" out="$2"
    local -n _args="$3"
    _args=()
    while IFS= read -r -d '' a; do _args+=("$a"); done \
        < <("${UNPACK[@]}" --boot_img "$img" --out "$out" --format=mkbootimg -0)
}

# Extract the RECOVERY fragment (type 2) of vendor_boot image $1 to file $2.
extract_recovery_fragment() {
    local img="$1" dest="$2" found="" i j
    local twrp_args=()
    read_args "$img" "$WORK/twrp" twrp_args
    for ((i = 0; i < ${#twrp_args[@]}; i++)); do
        if [[ "${twrp_args[i]}" == "--ramdisk_type" && "${twrp_args[i+1]}" == "2" ]]; then
            for ((j = i; j < ${#twrp_args[@]}; j++)); do
                if [[ "${twrp_args[j]}" == "--vendor_ramdisk_fragment" ]]; then
                    found="${twrp_args[j+1]}"; break
                fi
            done
            break
        fi
    done
    if [[ -z "$found" ]]; then
        echo "error: $img has no RECOVERY ramdisk fragment" >&2
        echo "       (was it built with BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT?)" >&2
        exit 1
    fi
    cp "$found" "$dest"
}

if [[ -n "$EXTRACT" ]]; then
    is_vendor_boot "$RECOVERY" || { echo "error: $RECOVERY is not a vendor_boot image" >&2; exit 1; }
    extract_recovery_fragment "$RECOVERY" "$EXTRACT"
    echo ">> Wrote $EXTRACT ($(stat -c %s "$EXTRACT") bytes)"
    exit 0
fi

is_vendor_boot "$STOCK" || { echo "error: $STOCK is not a vendor_boot image" >&2; exit 1; }

# Resolve the recovery ramdisk to use.
RECOVERY_RAMDISK="$WORK/recovery-ramdisk"
if is_vendor_boot "$RECOVERY"; then
    extract_recovery_fragment "$RECOVERY" "$RECOVERY_RAMDISK"
else
    cp "$RECOVERY" "$RECOVERY_RAMDISK"
fi

stock_args=()
read_args "$STOCK" "$WORK/stock" stock_args

# Rebuild the argument list, swapping the RECOVERY fragment (type 2).
new_args=()
replaced=0
pending_type=""
for ((i = 0; i < ${#stock_args[@]}; i++)); do
    a="${stock_args[i]}"
    case "$a" in
        --ramdisk_type)
            pending_type="${stock_args[i+1]}"
            new_args+=("$a" "$pending_type"); i=$((i + 1)) ;;
        --vendor_ramdisk_fragment)
            if [[ "$pending_type" == "2" ]]; then
                new_args+=("$a" "$RECOVERY_RAMDISK"); replaced=1
            else
                new_args+=("$a" "${stock_args[i+1]}")
            fi
            pending_type=""; i=$((i + 1)) ;;
        *)
            new_args+=("$a") ;;
    esac
done

if [[ "$replaced" == 0 ]]; then
    echo ">> Stock image has no recovery fragment, appending one"
    new_args+=(--ramdisk_type recovery --ramdisk_name recovery
               --vendor_ramdisk_fragment "$RECOVERY_RAMDISK")
else
    echo ">> Replacing stock recovery fragment"
fi

"${MKBOOTIMG[@]}" "${new_args[@]}" --vendor_boot "$OUTPUT"

size_stock="$(stat -c %s "$STOCK")"
size_new="$(stat -c %s "$OUTPUT")"
partition_size=$((64 * 1024 * 1024))
if ((size_new > partition_size)); then
    echo "error: result ($size_new bytes) is larger than the 64 MiB vendor_boot partition" >&2
    rm -f "$OUTPUT"
    exit 1
fi

echo ">> Wrote $OUTPUT ($size_new bytes, stock was $size_stock bytes)"
echo "   Flash with: scripts/flash.sh recovery $OUTPUT"
