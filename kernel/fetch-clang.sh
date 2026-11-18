#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Download the AOSP clang release used for android12-5.10 GKI kernels
# (clang-r416183b, LLVM 12). Newer host clang usually works too, but this
# matches what Motorola/MediaTek ship and avoids new-compiler warnings.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG_VERSION="${CLANG_VERSION:-clang-r416183b}"
BRANCH="${BRANCH:-android12-release}"
DEST="${1:-$ROOT/src/$CLANG_VERSION}"
URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/$BRANCH/$CLANG_VERSION.tar.gz"

if [[ -x "$DEST/bin/clang" ]]; then
    echo "clang already present at $DEST"
    exit 0
fi

mkdir -p "$DEST"
echo ">> Downloading $CLANG_VERSION ($BRANCH)"
curl -fsSL --retry 4 "$URL" | tar -xz -C "$DEST"
"$DEST/bin/clang" --version | head -1
echo ">> Use it with: kernel/build-kernel.sh -c $DEST"
