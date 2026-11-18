#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Replace the kernel (and optionally the ramdisk) inside the STOCK boot.img,
# keeping the header version, OS version/patch level and every other field.
#
# Usage:
#   repack-boot.sh -s stock_boot.img -k Image.gz [-r ramdisk.cpio.lz4] -o out.img
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="${TOOLS:-$ROOT/src/tools}"

STOCK="" KERNEL="" RAMDISK="" OUTPUT=""
usage() { sed -n '/^# Usage:/,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; }
while getopts "s:k:r:o:h" opt; do
    case "$opt" in
        s) STOCK="$(realpath "$OPTARG")" ;;
        k) KERNEL="$(realpath "$OPTARG")" ;;
        r) RAMDISK="$(realpath "$OPTARG")" ;;
        o) OUTPUT="$(realpath -m "$OPTARG")" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
[[ -n "$STOCK" && -n "$KERNEL" && -n "$OUTPUT" ]] || { usage; exit 1; }
for f in "$STOCK" "$KERNEL" ${RAMDISK:+"$RAMDISK"}; do
    [[ -f "$f" ]] || { echo "error: $f not found" >&2; exit 1; }
done
[[ "$(head -c 8 "$STOCK")" == "ANDROID!" ]] || { echo "error: $STOCK is not a boot image" >&2; exit 1; }

"$ROOT/scripts/fetch-tools.sh" --quiet

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

args=()
while IFS= read -r -d '' a; do args+=("$a"); done \
    < <(python3 "$TOOLS/mkbootimg/unpack_bootimg.py" --boot_img "$STOCK" --out "$WORK" --format=mkbootimg -0)

new_args=()
for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[i]}" in
        --kernel)  new_args+=(--kernel "$KERNEL"); i=$((i + 1)) ;;
        --ramdisk) new_args+=(--ramdisk "${RAMDISK:-${args[i+1]}}"); i=$((i + 1)) ;;
        *)         new_args+=("${args[i]}") ;;
    esac
done

python3 "$TOOLS/mkbootimg/mkbootimg.py" "${new_args[@]}" --output "$OUTPUT"

size="$(stat -c %s "$OUTPUT")"
if ((size > 64 * 1024 * 1024)); then
    echo "error: result ($size bytes) is larger than the 64 MiB boot partition" >&2
    rm -f "$OUTPUT"
    exit 1
fi
echo ">> Wrote $OUTPUT ($size bytes)"
echo "   Test:  fastboot boot $OUTPUT"
echo "   Flash: scripts/flash.sh kernel $OUTPUT"
