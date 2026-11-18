#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Sync and build LineageOS + the G73 Open flavor for the moto g73 5G (devonf).
#
# Usage:
#   rom/build-rom.sh [sync|build|all]      (default: all)
#
# Environment:
#   LINEAGE_DIR     source checkout (default: src/lineage)
#   LINEAGE_BRANCH  LineageOS branch (default: lineage-24.0)
#   VARIANT         user | userdebug | eng (default: userdebug)
#   TARGET_RELEASE  release config (default: LineageOS' aosp_target_release)
#   JOBS            parallel jobs (default: nproc)
#   WITH_FLAVOR     1 = install the G73 Open layer as vendor/extra (default: 1)
#
# Requirements: ~400 GB free disk, 32 GB RAM (+swap/zram), repo, git-lfs,
# and the AOSP build packages (see docs/build-rom.md).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINEAGE_DIR="${LINEAGE_DIR:-$ROOT/src/lineage}"
LINEAGE_BRANCH="${LINEAGE_BRANCH:-lineage-24.0}"
VARIANT="${VARIANT:-userdebug}"
JOBS="${JOBS:-$(nproc)}"
WITH_FLAVOR="${WITH_FLAVOR:-1}"
DEVICE=devonf
ACTION="${1:-all}"

die() { echo "error: $*" >&2; exit 1; }

do_sync() {
    command -v repo >/dev/null || die "'repo' not found (https://source.android.com/docs/setup/download)"
    mkdir -p "$LINEAGE_DIR"
    cd "$LINEAGE_DIR"
    if [[ ! -d .repo ]]; then
        echo ">> repo init LineageOS ($LINEAGE_BRANCH)"
        repo init -u https://github.com/LineageOS/android.git -b "$LINEAGE_BRANCH" \
            --git-lfs --no-clone-bundle
    fi
    mkdir -p .repo/local_manifests
    cp "$ROOT/rom/local_manifests/devonf.xml" .repo/local_manifests/devonf.xml
    echo ">> repo sync (this takes a while)"
    repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags
}

install_flavor() {
    local dest="$LINEAGE_DIR/vendor/extra"
    if [[ -e "$dest" && ! -f "$dest/.g73open" ]]; then
        die "$dest exists and is not managed by this project; move it away first"
    fi
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -r "$ROOT/rom/vendor/extra/." "$dest/"
    touch "$dest/.g73open"
    echo ">> Installed G73 Open flavor into vendor/extra"
}

do_build() {
    [[ -f "$LINEAGE_DIR/build/envsetup.sh" ]] || die "no source tree at $LINEAGE_DIR (run: $0 sync)"
    [[ -d "$LINEAGE_DIR/device/motorola/$DEVICE" ]] || die "device tree missing (run: $0 sync)"
    if [[ "$WITH_FLAVOR" == 1 ]]; then
        install_flavor
    elif [[ -f "$LINEAGE_DIR/vendor/extra/.g73open" ]]; then
        rm -rf "$LINEAGE_DIR/vendor/extra"
        echo ">> Removed G73 Open flavor (plain LineageOS build)"
    fi
    if [[ ! -f "$LINEAGE_DIR/vendor/lineage-priv/keys/keys.mk" ]]; then
        echo "warning: no private signing keys found; the build will use public test keys."
        echo "         Run rom/gen-keys.sh before building anything you install daily."
    fi

    cd "$LINEAGE_DIR"
    set +u
    # shellcheck disable=SC1091
    source build/envsetup.sh
    if [[ -z "${TARGET_RELEASE:-}" ]]; then
        # shellcheck disable=SC1091
        source vendor/lineage/vars/aosp_target_release
        TARGET_RELEASE="${aosp_target_release:?not set by vendor/lineage/vars/aosp_target_release}"
    fi
    lunch "lineage_${DEVICE}-${TARGET_RELEASE}-${VARIANT}"
    m -j"$JOBS" bacon
    set -u

    echo
    echo ">> Build finished. Artifacts in $OUT:"
    ls -1 "$OUT"/lineage-*.zip "$OUT"/boot.img "$OUT"/vendor_boot.img "$OUT"/dtbo.img 2>/dev/null || true
    echo "   Install guide: docs/install-rom.md"
}

case "$ACTION" in
    sync)  do_sync ;;
    build) do_build ;;
    all)   do_sync; do_build ;;
    *)     sed -n '/^# Usage:/,/^# Requirements/p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
