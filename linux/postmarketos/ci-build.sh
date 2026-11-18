#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Build the postmarketOS image for the Motorola moto g73 5G (devonf) with
# pmbootstrap, non-interactively. Used by .github/workflows/postmarketos.yml,
# but works locally too (WARNING: it rewrites your pmbootstrap config, and
# zaps chroots; set PMB_WORK to use a separate work directory).
#
# Usage:
#   [PMB_WORK=/path/to/work] ci-build.sh UI OUTDIR
#
# Output in OUTDIR (release assets):
#   linux-motorola-devonf-*.apk, device-motorola-devonf-*.apk (aarch64)
#   devonf-pmos-UI-rootfs.img.xz   (absent when image creation is impossible)
#   devonf-pmos-boot.img, devonf-pmos-vendor_boot.img (if produced)
# and, not as a release asset, ../pmos-meta/APKBUILD.linux-motorola-devonf
# (the kernel APKBUILD with the real tarball checksum).
#
# No signing keys (config_abuild) are ever copied to the output.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="motorola-devonf"

die() {
    echo "error: $*" >&2
    exit 1
}

[[ $# -eq 2 ]] || die "usage: $(basename "$0") UI OUTDIR"
UI="$1"
OUTDIR="$2"
[[ -n "$UI" && "$UI" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid UI: '$UI'"
command -v pmbootstrap >/dev/null 2>&1 || die "pmbootstrap not found in PATH"

mkdir -p "$OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd)"
META_DIR="$OUTDIR/../pmos-meta"
mkdir -p "$META_DIR"
META_DIR="$(cd "$META_DIR" && pwd)"

# -y: assume yes; -t: do not kill silent long compiles (CI defaults to 900s)
PMB_OPTS=(--details-to-stdout -y -t 7200)
if [[ -n "${PMB_WORK:-}" ]]; then
    mkdir -p "$PMB_WORK"
    PMB_WORK="$(cd "$PMB_WORK" && pwd)"
    PMB_OPTS+=(--work "$PMB_WORK")
fi

pmb() {
    echo "+ pmbootstrap $*"
    pmbootstrap "${PMB_OPTS[@]}" "$@"
}

# 'init' reads its prompts from stdin; accept all defaults (the work path
# default is --work). Process substitution avoids SIGPIPE from 'yes' under
# pipefail. init does not take -y.
echo "+ pmbootstrap init --shallow-initial-clone"
pmbootstrap --details-to-stdout ${PMB_WORK:+--work "$PMB_WORK"} \
    init --shallow-initial-clone < <(yes '')

# Copy both packages into pmaports and fill the checksums (this downloads the
# kernel tarball and writes its sha512 into the APKBUILD).
"$HERE/pmaports-import.sh" --force

# 'pmbootstrap config' ignores command line overrides and edits the saved
# config, which init has just written.
pmbootstrap config device "$DEVICE"
pmbootstrap config ui "$UI"
pmbootstrap config build_pkgs_on_install true

APORTS="$(pmbootstrap config aports)"
WORK="$(pmbootstrap config work)"
[[ -d "$APORTS" && -n "$WORK" ]] || die "could not determine aports/work paths"

pmb build --force linux-motorola-devonf device-motorola-devonf

# Keep the kernel APKBUILD with the real checksum for later commit.
cp "$APORTS/device/downstream/linux-motorola-devonf/APKBUILD" \
    "$META_DIR/APKBUILD.linux-motorola-devonf"

# Image creation needs loop devices, which may be missing; fall back to only
# setting up the rootfs chroot (boot.img is still generated in it).
HAVE_IMAGE=1
if ! pmb install --password 147147 --zap; then
    echo "warning: image creation failed; retrying with --no-image" >&2
    HAVE_IMAGE=0
    pmb install --password 147147 --zap --no-image
fi

# Blob guard: no proprietary firmware package may be in the rootfs.
installed="$(pmb chroot --output stdout -r -- apk info)"
grep -qx 'postmarketos-base' <<<"$installed" \
    || die "could not list the packages installed in the rootfs"
if bad="$(grep -E '^(linux-firmware|firmware-)' <<<"$installed")"; then
    echo "$bad" >&2
    die "firmware packages found in the rootfs (blobs must not be shipped)"
fi

EXPORT_DIR="$(mktemp -d)"
trap 'rm -rf "$EXPORT_DIR"' EXIT
pmb export "$EXPORT_DIR"
pmb shutdown

# Work dir contents are root-owned: copy (dereferencing the export symlinks)
# with sudo, then hand the files to the current user.
sudo_cp() { sudo cp -L "$1" "$2"; }

n_apk=0
while IFS= read -r -d '' f; do
    sudo_cp "$f" "$OUTDIR/"
    n_apk=$((n_apk + 1))
done < <(sudo find "$WORK/packages" -type f -path '*/aarch64/*' \
    \( -name 'linux-motorola-devonf-*.apk' -o -name 'device-motorola-devonf-*.apk' \) \
    -print0)
[[ "$n_apk" -gt 0 ]] || die "no built apks found under $WORK/packages"

if [[ "$HAVE_IMAGE" -eq 1 ]]; then
    if sudo test -e "$EXPORT_DIR/$DEVICE.img"; then
        # Android sparse image, flash with 'fastboot flash userdata'
        sudo xz -T0 -c "$EXPORT_DIR/$DEVICE.img" \
            | cat > "$OUTDIR/devonf-pmos-$UI-rootfs.img.xz"
    else
        echo "warning: no rootfs image was exported" >&2
    fi
else
    echo "note: no rootfs image (image creation failed)" >&2
fi

sudo test -e "$EXPORT_DIR/boot.img" || die "boot.img was not produced"
sudo_cp "$EXPORT_DIR/boot.img" "$OUTDIR/devonf-pmos-boot.img"
if sudo test -e "$EXPORT_DIR/vendor_boot.img"; then
    sudo_cp "$EXPORT_DIR/vendor_boot.img" "$OUTDIR/devonf-pmos-vendor_boot.img"
fi

sudo chown -R "$(id -u):$(id -g)" "$OUTDIR" "$META_DIR"

echo "Output:"
ls -l "$OUTDIR" "$META_DIR"
