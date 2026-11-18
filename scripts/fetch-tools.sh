#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Fetch host tools used by the helper scripts into src/tools:
#   - AOSP mkbootimg / unpack_bootimg (boot + vendor_boot v4 support)
#
# Other required host packages (install with your package manager):
#   android-sdk-platform-tools (adb, fastboot), lz4, cpio, unzip, python3,
#   simg2img + lpunpack (android-sdk-libsparse-utils / lpunpack) for super.img
#
set -euo pipefail

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="${TOOLS:-$ROOT/src/tools}"
MKBOOTIMG_REPO="https://android.googlesource.com/platform/system/tools/mkbootimg"

mkdir -p "$TOOLS"
if [[ ! -f "$TOOLS/mkbootimg/mkbootimg.py" ]]; then
    echo ">> Fetching AOSP mkbootimg tools"
    git clone --depth 1 "$MKBOOTIMG_REPO" "$TOOLS/mkbootimg" >&2
fi

missing=()
for tool in python3 lz4 cpio unzip; do
    command -v "$tool" >/dev/null || missing+=("$tool")
done
if ((${#missing[@]})); then
    echo "warning: missing host tools: ${missing[*]}" >&2
fi
[[ "$QUIET" == 1 ]] && exit 0
for tool in fastboot adb; do
    command -v "$tool" >/dev/null || echo "note: '$tool' not found (needed only for flashing)" >&2
done

echo ">> Tools ready in $TOOLS"
