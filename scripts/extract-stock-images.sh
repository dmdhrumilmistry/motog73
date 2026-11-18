#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Extract the images needed by this project from YOUR OWN stock firmware.
# Nothing extracted here may be committed: the output directories are
# git-ignored on purpose (proprietary / device-specific data).
#
# Input: the official Motorola fastboot firmware for your exact build
#        (e.g. the package for U1TNS34.82-12-7-26 for your model / region),
#        either as the .zip or as an already-extracted directory.
#
# Output (default: stock/<build-or-name>/):
#   images/      boot.img vendor_boot.img dtbo.img vbmeta*.img flashfile.xml
#   boot/        unpacked boot.img        (kernel, mkbootimg args)
#   vendor_boot/ unpacked vendor_boot.img (dtb, ramdisk fragments, args)
#   vendor_ramdisk/  extracted platform vendor ramdisk (modules, fstab, ...)
#   prebuilt/    kernel, dtb/, modules/ in the layout the TWRP tree expects
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="${TOOLS:-$ROOT/src/tools}"

usage() {
    echo "Usage: $(basename "$0") <firmware.zip | firmware-dir> [output-dir]"
}

[[ $# -ge 1 ]] || { usage; exit 1; }
INPUT="$(realpath "$1")"
NAME="$(basename "${INPUT%.zip}")"
OUTDIR="$(realpath -m "${2:-$ROOT/stock/$NAME}")"

"$ROOT/scripts/fetch-tools.sh" --quiet
UNPACK=(python3 "$TOOLS/mkbootimg/unpack_bootimg.py")

IMAGES=(boot.img vendor_boot.img dtbo.img vbmeta.img vbmeta_system.img flashfile.xml)

mkdir -p "$OUTDIR/images"
if [[ -f "$INPUT" ]]; then
    echo ">> Extracting images from $(basename "$INPUT")"
    for img in "${IMAGES[@]}"; do
        unzip -o -j -q "$INPUT" "$img" -d "$OUTDIR/images" 2>/dev/null \
            || echo "   note: $img not found in archive"
    done
elif [[ -d "$INPUT" ]]; then
    for img in "${IMAGES[@]}"; do
        if [[ -f "$INPUT/$img" ]]; then cp "$INPUT/$img" "$OUTDIR/images/"
        else echo "   note: $img not found in $INPUT"; fi
    done
else
    echo "error: $INPUT is neither a file nor a directory" >&2
    exit 1
fi

for img in boot.img vendor_boot.img; do
    [[ -f "$OUTDIR/images/$img" ]] || { echo "error: $img is required" >&2; exit 1; }
done

echo ">> Unpacking boot.img"
rm -rf "${OUTDIR:?}/boot" "${OUTDIR:?}/vendor_boot" "${OUTDIR:?}/vendor_ramdisk" "${OUTDIR:?}/prebuilt"
"${UNPACK[@]}" --boot_img "$OUTDIR/images/boot.img" --out "$OUTDIR/boot" > "$OUTDIR/boot-info.txt"
"${UNPACK[@]}" --boot_img "$OUTDIR/images/boot.img" --out "$OUTDIR/boot" --format=mkbootimg > "$OUTDIR/boot-mkbootimg-args.txt"

echo ">> Unpacking vendor_boot.img"
"${UNPACK[@]}" --boot_img "$OUTDIR/images/vendor_boot.img" --out "$OUTDIR/vendor_boot" > "$OUTDIR/vendor_boot-info.txt"
"${UNPACK[@]}" --boot_img "$OUTDIR/images/vendor_boot.img" --out "$OUTDIR/vendor_boot" --format=mkbootimg > "$OUTDIR/vendor_boot-mkbootimg-args.txt"

# Decompress a ramdisk (lz4 legacy or gzip) into a directory.
extract_ramdisk() {
    local src="$1" dest="$2" magic
    mkdir -p "$dest"
    magic="$(od -An -tx1 -N4 "$src" | tr -d ' \n')"
    case "$magic" in
        02214c18|04224d18) lz4 -dc "$src" ;;
        1f8b*)             gzip -dc "$src" ;;
        *)                 cat "$src" ;;
    esac | (cd "$dest" && cpio -idm --no-absolute-filenames --quiet)
}

echo ">> Extracting vendor ramdisk fragments"
shopt -s nullglob
fragments=("$OUTDIR"/vendor_boot/vendor_ramdisk*)
if ((${#fragments[@]} == 0)); then
    echo "error: no vendor ramdisk found in vendor_boot.img" >&2
    exit 1
fi
for frag in "${fragments[@]}"; do
    extract_ramdisk "$frag" "$OUTDIR/vendor_ramdisk/$(basename "$frag")"
done

echo ">> Collecting prebuilts"
mkdir -p "$OUTDIR/prebuilt/dtb" "$OUTDIR/prebuilt/modules"
cp "$OUTDIR/boot/kernel" "$OUTDIR/prebuilt/kernel"
if [[ -f "$OUTDIR/vendor_boot/dtb" ]]; then
    cp "$OUTDIR/vendor_boot/dtb" "$OUTDIR/prebuilt/dtb/mt6855.dtb"
fi
[[ -f "$OUTDIR/images/dtbo.img" ]] && cp "$OUTDIR/images/dtbo.img" "$OUTDIR/prebuilt/dtbo.img"
while IFS= read -r -d '' moddir; do
    cp "$moddir"/*.ko "$OUTDIR/prebuilt/modules/" 2>/dev/null || true
    for list in modules.load modules.load.recovery modules.dep modules.alias modules.softdep; do
        [[ -f "$moddir/$list" ]] && cp "$moddir/$list" "$OUTDIR/prebuilt/modules/"
    done
done < <(find "$OUTDIR/vendor_ramdisk" -type d -path '*lib/modules*' -print0)

nmods="$(find "$OUTDIR/prebuilt/modules" -name '*.ko' | wc -l)"
echo ">> Done."
echo "   images:   $OUTDIR/images"
echo "   prebuilt: $OUTDIR/prebuilt ($nmods modules)"
echo
echo "To use them for the TWRP tree:"
echo "   cp -r $OUTDIR/prebuilt <twrp-source>/device/motorola/devonf/prebuilt"
