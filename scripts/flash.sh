#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Safe fastboot helpers for the moto g73 5G (devonf).
# Every command first checks that the connected device really is a devonf.
#
# Commands:
#   check                      show device state (product, slot, unlock state)
#   backup-hint                how to keep a copy of your stock images
#   recovery <vendor_boot.img> flash a vendor_boot that contains a custom recovery
#   boot-recovery              reboot into recovery from fastboot
#   kernel <boot.img>          flash a custom boot image (kernel) to the active slot
#   gsi <system.img>           flash a Generic System Image (GSI) via fastbootd
#   rom <rom.zip>              sideload a recovery-flashable ROM zip (device in recovery)
#   linux <boot.img> <rootfs>  flash a Linux (postmarketOS) boot + rootfs
#   restore <firmware-dir>     restore stock firmware (see moto-flashfile.py)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_PRODUCT="devonf"
FASTBOOT=(fastboot)
[[ -n "${ANDROID_SERIAL:-}" ]] && FASTBOOT+=(-s "$ANDROID_SERIAL")

die() { echo "error: $*" >&2; exit 1; }

usage() {
    sed -n '/^# Commands:/,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'
}

getvar() {
    "${FASTBOOT[@]}" getvar "$1" 2>&1 | awk -F': ' -v k="$1" '$1==k {print $2; exit}'
}

require_device() {
    command -v fastboot >/dev/null || die "fastboot not found (install android platform-tools)"
    local product
    product="$(getvar product)"
    [[ -n "$product" ]] || die "no device in fastboot mode (adb reboot bootloader)"
    [[ "$product" == "$EXPECTED_PRODUCT" ]] \
        || die "connected device is '$product', not '$EXPECTED_PRODUCT' (moto g73 5G). Aborting."
}

require_unlocked() {
    local unlocked
    unlocked="$(getvar unlocked)"
    [[ "$unlocked" == "yes" ]] || die "bootloader is locked. See docs/unlock-bootloader.md"
}

confirm() {
    [[ "${ASSUME_YES:-0}" == 1 ]] && return 0
    read -r -p "$1 [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || die "aborted by user"
}

require_file() { [[ -f "$1" ]] || die "file not found: $1"; }

cmd="${1:-}"
shift || true

case "$cmd" in
    check)
        require_device
        for v in product current-slot unlocked securestate slot-count is-userspace; do
            printf '%-14s %s\n' "$v:" "$(getvar "$v")"
        done
        ;;

    backup-hint)
        cat <<'EOF'
Keep the complete stock firmware package for YOUR build (same model, region
and build number as `adb shell getprop ro.build.fingerprint`). It contains
boot.img, vendor_boot.img, dtbo.img, vbmeta*.img and super chunks, and lets
you return to stock at any time:

    scripts/moto-flashfile.py <extracted-firmware-dir>            # dry run
    scripts/moto-flashfile.py <extracted-firmware-dir> --execute

Never share these images publicly: they can contain region/carrier data.
EOF
        ;;

    recovery)
        img="${1:-}"; require_file "$img"
        [[ "$(head -c 8 "$img" | tr -d '\0')" == "VNDRBOOT" ]] || die "$img is not a vendor_boot image"
        require_device; require_unlocked
        slot="$(getvar current-slot)"
        echo "This flashes $img to vendor_boot_$slot (active slot)."
        echo "Keep your stock vendor_boot.img to undo: fastboot flash vendor_boot_$slot vendor_boot.img"
        confirm "Continue?"
        "${FASTBOOT[@]}" flash "vendor_boot_$slot" "$img"
        echo "Done. Boot recovery with: $0 boot-recovery  (or hold Vol- + Power, select Recovery mode)"
        ;;

    boot-recovery)
        require_device
        "${FASTBOOT[@]}" reboot recovery
        ;;

    kernel)
        img="${1:-}"; require_file "$img"
        [[ "$(head -c 8 "$img")" == "ANDROID!" ]] || die "$img is not an Android boot image"
        require_device; require_unlocked
        slot="$(getvar current-slot)"
        confirm "Flash $img to boot_$slot?"
        "${FASTBOOT[@]}" flash "boot_$slot" "$img"
        ;;

    gsi)
        img="${1:-}"; require_file "$img"
        require_device; require_unlocked
        if [[ "$(getvar is-userspace)" != "yes" ]]; then
            echo ">> Rebooting to fastbootd (userspace fastboot) for dynamic partitions"
            "${FASTBOOT[@]}" reboot fastboot
            sleep 5
            require_device
        fi
        echo "This replaces the system partition with $img and wipes user data."
        confirm "Continue?"
        # Free space in super for the (usually larger) GSI system image.
        slot="$(getvar current-slot)"
        "${FASTBOOT[@]}" delete-logical-partition "product_$slot" 2>/dev/null || true
        "${FASTBOOT[@]}" flash system "$img"
        "${FASTBOOT[@]}" -w
        echo "Done. Reboot with: fastboot reboot"
        ;;

    rom)
        zip="${1:-}"; require_file "$zip"
        command -v adb >/dev/null || die "adb not found"
        echo "Put the device in recovery -> 'Apply update' -> 'Apply from ADB', then press Enter."
        read -r
        adb sideload "$zip"
        ;;

    linux)
        boot="${1:-}" rootfs="${2:-}"
        require_file "$boot"; require_file "$rootfs"
        require_device; require_unlocked
        echo "This replaces boot and USERDATA with a Linux image. Android data will be lost."
        confirm "Continue?"
        slot="$(getvar current-slot)"
        "${FASTBOOT[@]}" flash "boot_$slot" "$boot"
        "${FASTBOOT[@]}" flash userdata "$rootfs"
        ;;

    restore)
        dir="${1:-}"; [[ -d "$dir" ]] || die "firmware directory not found: $dir"
        shift
        python3 "$ROOT/scripts/moto-flashfile.py" "$dir" "$@"
        ;;

    ""|-h|--help|help)
        usage
        ;;

    *)
        usage; exit 1
        ;;
esac
