#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Build TWRP for the moto g73 5G (devonf) and inject it into your stock
# vendor_boot.img.
#
# Usage:
#   recovery/build-twrp.sh <stock-dir>
#   recovery/build-twrp.sh -k <dist-dir>
#
#   <stock-dir> is the output of scripts/extract-stock-images.sh
#   (it must contain images/vendor_boot.img and prebuilt/).
#
#   -k <dist-dir> is the CI mode, no stock firmware needed: <dist-dir> holds
#   Image.gz and mt6855.dtb from our own source kernel build. The stock repack
#   is skipped; OUT_DIR (default: out/recovery) receives
#   twrp-devonf-recovery-ramdisk.cpio.lz4 and twrp-devonf-vendor_boot-raw.img.
#   The raw image is NOT a flashable vendor_boot (no stock fragments).
#
# Environment:
#   TWRP_DIR      TWRP source checkout (default: src/twrp)
#   TWRP_BRANCH   minimal manifest branch (default: twrp-14.1)
#   OUT_DIR       CI mode output directory (default: out/recovery)
#   JOBS          parallel jobs (default: nproc)
#
# Needs ~60 GB of disk and the usual AOSP build dependencies.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TWRP_DIR="${TWRP_DIR:-$ROOT/src/twrp}"
TWRP_BRANCH="${TWRP_BRANCH:-twrp-14.1}"
MANIFEST="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git"
JOBS="${JOBS:-$(nproc)}"

usage() { sed -n '/^# Usage:/,/^# Needs/p' "$0" | sed 's/^# \{0,1\}//'; }
KDIST=""
while getopts "k:h" opt; do
    case "$opt" in
        k) KDIST="$(realpath "$OPTARG")" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))
STOCK=""
if [[ -n "$KDIST" ]]; then
    [[ $# -eq 0 ]] || { usage; exit 1; }
    [[ -f "$KDIST/Image.gz" ]] || { echo "error: $KDIST/Image.gz missing" >&2; exit 1; }
    [[ -f "$KDIST/mt6855.dtb" ]] || { echo "error: $KDIST/mt6855.dtb missing" >&2; exit 1; }
else
    [[ $# -eq 1 ]] || { usage; exit 1; }
    STOCK="$(realpath "$1")"
    [[ -f "$STOCK/images/vendor_boot.img" ]] || { echo "error: $STOCK/images/vendor_boot.img missing" >&2; exit 1; }
    [[ -f "$STOCK/prebuilt/kernel" ]] || { echo "error: $STOCK/prebuilt missing (run scripts/extract-stock-images.sh)" >&2; exit 1; }
fi
command -v repo >/dev/null || { echo "error: 'repo' not found (https://source.android.com/docs/setup/download)" >&2; exit 1; }

mkdir -p "$TWRP_DIR"
cd "$TWRP_DIR"
if [[ ! -d .repo ]]; then
    echo ">> Initialising TWRP minimal manifest ($TWRP_BRANCH)"
    repo init --depth=1 -u "$MANIFEST" -b "$TWRP_BRANCH" --git-lfs
fi
echo ">> Syncing sources"
repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags

echo ">> Installing device tree and prebuilts"
DEV="$TWRP_DIR/device/motorola/devonf"
rm -rf "$DEV"
mkdir -p "$DEV"
cp -r "$ROOT/recovery/twrp/device/motorola/devonf/." "$DEV/"
if [[ -n "$KDIST" ]]; then
    mkdir -p "$DEV/prebuilt/dtb"
    cp "$KDIST/Image.gz" "$DEV/prebuilt/kernel"
    cp "$KDIST/mt6855.dtb" "$DEV/prebuilt/dtb/mt6855.dtb"
else
    cp -r "$STOCK/prebuilt" "$DEV/prebuilt"
fi

echo ">> Building vendor_boot (recovery ramdisk)"
set +u
# shellcheck disable=SC1091
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunched=0
lunch_log="$(mktemp)"
for target in twrp_devonf-eng twrp_devonf-ap2a-eng twrp_devonf-trunk_staging-eng; do
    echo "   trying: lunch $target"
    if lunch "$target" >"$lunch_log" 2>&1; then
        echo "   lunch $target"
        lunched=1
        break
    fi
    sed 's/^/     | /' "$lunch_log" | tail -n 40 >&2
done
rm -f "$lunch_log"
[[ "$lunched" == 1 ]] || { echo "error: lunch failed for twrp_devonf (output above)" >&2; exit 1; }
m -j"$JOBS" vendorbootimage
set -u

BUILT="$OUT/vendor_boot.img"
[[ -f "$BUILT" ]] || { echo "error: build did not produce $BUILT" >&2; exit 1; }

if [[ -n "$KDIST" ]]; then
    CI_OUT="${OUT_DIR:-$ROOT/out/recovery}"
    mkdir -p "$CI_OUT"
    "$ROOT/scripts/repack-vendor-boot.sh" -e "$CI_OUT/twrp-devonf-recovery-ramdisk.cpio.lz4" -r "$BUILT"
    cp "$BUILT" "$CI_OUT/twrp-devonf-vendor_boot-raw.img"
    echo
    echo ">> TWRP built (CI mode), output in $CI_OUT"
    exit 0
fi

RESULT="$ROOT/out/recovery/twrp-devonf-vendor_boot.img"
mkdir -p "$(dirname "$RESULT")"
"$ROOT/scripts/repack-vendor-boot.sh" -s "$STOCK/images/vendor_boot.img" -r "$BUILT" -o "$RESULT"

echo
echo ">> TWRP ready: $RESULT"
echo "   Flash: scripts/flash.sh recovery $RESULT"
echo "   Undo:  fastboot flash vendor_boot_<slot> $STOCK/images/vendor_boot.img"
