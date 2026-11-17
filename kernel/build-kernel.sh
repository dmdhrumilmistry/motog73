#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Build the moto g73 5G (devonf) kernel from Motorola's open source release.
#
# Produces in $OUT/dist:
#   Image.gz            kernel image (boot.img payload)
#   modules/            in-tree kernel modules (stripped)
#   config              final kernel .config
#   kernel.release      kernel release string
#
# DTB/DTBO are NOT built here: MediaTek generates the board DTS includes
# (devonf_evb/cust.dtsi) with a proprietary DCT tool during the Android build.
# Re-use the dtb/dtbo from your own stock firmware instead
# (see scripts/extract-stock-images.sh).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TAG="${TAG:-MMI-U1TNS34.82-12-7-26}"
REPO_URL="${REPO_URL:-https://github.com/MotorolaMobilityLLC/kernel-mtk}"
SRC="${SRC:-$ROOT/src/kernel-5.10}"
OUT="${OUT:-$ROOT/out/kernel}"
VARIANT="${VARIANT:-user}"
JOBS="${JOBS:-$(nproc)}"
CLANG_DIR="${CLANG_DIR:-}"
FRAGMENTS=()
TARGETS=(Image.gz modules)

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -t TAG        Motorola kernel tag to build (default: $TAG)
  -s DIR        kernel source directory (default: src/kernel-5.10, cloned if missing)
  -o DIR        output directory (default: out/kernel)
  -v VARIANT    user | userdebug (userdebug adds Motorola debug fragments)
  -f FILE       extra config fragment to merge (repeatable)
  -p            merge kernel/configs/postmarketos.config (Linux flavor)
  -g            merge kernel/configs/g73open.config (custom ROM flavor)
  -c DIR        clang toolchain directory (e.g. AOSP clang-r416183b);
                use kernel/fetch-clang.sh to download it
  -k            only generate the .config (no compile)
  -j N          parallel jobs (default: $JOBS)
  -h            show this help
EOF
}

CONFIG_ONLY=0
while getopts "t:s:o:v:f:pgc:kj:h" opt; do
    case "$opt" in
        t) TAG="$OPTARG" ;;
        s) SRC="$OPTARG" ;;
        o) OUT="$OPTARG" ;;
        v) VARIANT="$OPTARG" ;;
        f) FRAGMENTS+=("$(realpath "$OPTARG")") ;;
        p) FRAGMENTS+=("$ROOT/kernel/configs/postmarketos.config") ;;
        g) FRAGMENTS+=("$ROOT/kernel/configs/g73open.config") ;;
        c) CLANG_DIR="$OPTARG" ;;
        k) CONFIG_ONLY=1 ;;
        j) JOBS="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

case "$VARIANT" in
    user|userdebug) ;;
    *) echo "error: VARIANT must be 'user' or 'userdebug'" >&2; exit 1 ;;
esac

if [[ -n "$CLANG_DIR" ]]; then
    CLANG_DIR="$(realpath "$CLANG_DIR")"
    export PATH="$CLANG_DIR/bin:$PATH"
fi

for tool in clang ld.lld llvm-ar make bc flex bison perl; do
    command -v "$tool" >/dev/null || { echo "error: '$tool' not found in PATH" >&2; exit 1; }
done

if [[ ! -f "$SRC/Makefile" ]]; then
    echo ">> Cloning $REPO_URL ($TAG) into $SRC"
    git clone --depth 1 --branch "$TAG" "$REPO_URL" "$SRC"
fi

mkdir -p "$OUT"
OUT="$(realpath "$OUT")"

MAKE=(make -C "$SRC" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1
      CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
      KBUILD_BUILD_USER=builder KBUILD_BUILD_HOST=motog73
      -j"$JOBS")

EXT="$SRC/arch/arm64/configs/ext_config"
# Same order MediaTek's scripts/gen_build_config.py uses:
#   gki_defconfig + mgk_64_k510_defconfig + Motorola overlays (+ debug overlays)
CONFIGS=("$SRC/arch/arm64/configs/mgk_64_k510_defconfig"
         "$EXT/moto-mgk_64_k510.config" "$EXT/moto-mgk_64_k510-devonf.config")
if [[ "$VARIANT" == "userdebug" ]]; then
    CONFIGS+=("$EXT/debug-mgk_64_k510.config" "$EXT/debug-mgk_64_k510-devonf.config"
              "$SRC/kernel/configs/userdebug.config")
fi
CONFIGS+=("${FRAGMENTS[@]}")

for f in "${CONFIGS[@]}"; do
    [[ -f "$f" ]] || { echo "error: config fragment not found: $f" >&2; exit 1; }
done

echo ">> Generating base config (gki_defconfig)"
"${MAKE[@]}" gki_defconfig

echo ">> Merging fragments:"
printf '     %s\n' "${CONFIGS[@]}"
(cd "$SRC" && ARCH=arm64 scripts/kconfig/merge_config.sh -m -O "$OUT" "$OUT/.config" "${CONFIGS[@]}")
"${MAKE[@]}" olddefconfig

# Warn about requested options that Kconfig dropped (missing dependencies).
for frag in "${FRAGMENTS[@]}"; do
    name="$(basename "$frag")"
    while IFS= read -r line; do
        [[ "$line" =~ ^CONFIG_[A-Za-z0-9_]+= ]] || continue
        if ! grep -qxF "$line" "$OUT/.config"; then
            echo "   warning: $name: '$line' not applied" >&2
        fi
    done < "$frag"
done

if [[ "$CONFIG_ONLY" == 1 ]]; then
    echo ">> Config written to $OUT/.config"
    exit 0
fi

echo ">> Building ${TARGETS[*]} with $JOBS jobs"
"${MAKE[@]}" "${TARGETS[@]}"

DIST="$OUT/dist"
rm -rf "$DIST"
mkdir -p "$DIST/modules"
cp "$OUT/arch/arm64/boot/Image.gz" "$DIST/"
cp "$OUT/.config" "$DIST/config"
cp "$OUT/include/config/kernel.release" "$DIST/kernel.release"
"${MAKE[@]}" INSTALL_MOD_PATH="$DIST/modules" INSTALL_MOD_STRIP=1 modules_install
rm -f "$DIST"/modules/lib/modules/*/build "$DIST"/modules/lib/modules/*/source

echo ">> Done: $DIST (kernel $(cat "$DIST/kernel.release"))"
