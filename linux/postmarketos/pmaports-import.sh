#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Import the postmarketOS packages of this project (device-motorola-devonf and
# linux-motorola-devonf, located next to this script) into a pmaports checkout
# and drive pmbootstrap for the Motorola moto g73 5G (devonf).
#
# Usage:
#   pmaports-import.sh [--pmaports DIR] [--category downstream] [--force]
#                      [--dry-run] [--build] [--install] [--kconfig-check]
#                      [-h|--help]
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(device-motorola-devonf linux-motorola-devonf)

PMAPORTS=""
CATEGORY="downstream"
FORCE=0
DRY_RUN=0
DO_BUILD=0
DO_INSTALL=0
DO_KCONFIG=0

usage() {
    cat <<USAGE
Usage: $(basename "$0") [options]

Copy device-motorola-devonf and linux-motorola-devonf into a pmaports
checkout and run pmbootstrap checksum on them.

Options:
  --pmaports DIR     pmaports checkout (default: 'pmbootstrap config aports')
  --category NAME    device/<NAME>/ target category (default: downstream)
  --force            replace packages that already exist in the checkout
  --dry-run          copy, but only print the pmbootstrap commands
  --build            pmbootstrap build --force both packages
  --install          pmbootstrap install
  --kconfig-check    pmbootstrap kconfig check linux-motorola-devonf
  -h, --help         show this help
USAGE
}

die() {
    echo "error: $*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pmaports)
            [[ $# -ge 2 ]] || die "--pmaports needs an argument"
            PMAPORTS="$2"; shift 2 ;;
        --category)
            [[ $# -ge 2 ]] || die "--category needs an argument"
            CATEGORY="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --build) DO_BUILD=1; shift ;;
        --install) DO_INSTALL=1; shift ;;
        --kconfig-check) DO_KCONFIG=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown option: $1" ;;
    esac
done

[[ -n "$CATEGORY" && "$CATEGORY" != */* && "$CATEGORY" != .* ]] \
    || die "invalid category: '$CATEGORY'"

have_pmbootstrap() { command -v pmbootstrap >/dev/null 2>&1; }

if [[ -z "$PMAPORTS" ]]; then
    have_pmbootstrap \
        || die "pmbootstrap not found in PATH; install it or pass --pmaports DIR"
    PMAPORTS="$(pmbootstrap config aports)" \
        || die "'pmbootstrap config aports' failed; pass --pmaports DIR"
    [[ -n "$PMAPORTS" ]] || die "pmbootstrap returned an empty aports path"
fi

[[ -d "$PMAPORTS" ]] || die "pmaports directory not found: $PMAPORTS"
PMAPORTS="$(cd "$PMAPORTS" && pwd)"
if [[ ! -d "$PMAPORTS/device" ]] \
    || { [[ ! -f "$PMAPORTS/deviceinfo_schema.toml" ]] && [[ ! -f "$PMAPORTS/pmaports.cfg" ]]; }; then
    die "$PMAPORTS does not look like pmaports (need device/ and deviceinfo_schema.toml or pmaports.cfg)"
fi

if [[ "$DRY_RUN" -eq 0 ]] && ! have_pmbootstrap; then
    die "pmbootstrap not found in PATH (use --dry-run to only print commands)"
fi

DEST="$PMAPORTS/device/$CATEGORY"

for pkg in "${PACKAGES[@]}"; do
    [[ -d "$HERE/$pkg" ]] || die "package directory missing: $HERE/$pkg"
    if [[ -e "$DEST/$pkg" && "$FORCE" -eq 0 ]]; then
        die "$DEST/$pkg already exists (use --force to replace it)"
    fi
done

mkdir -p "$DEST"
for pkg in "${PACKAGES[@]}"; do
    if [[ -e "$DEST/$pkg" ]]; then
        echo "Replacing $DEST/$pkg"
        rm -rf "${DEST:?}/$pkg"
    else
        echo "Copying $pkg -> $DEST/"
    fi
    cp -a "$HERE/$pkg" "$DEST/$pkg"
done

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "+ $*"
    else
        echo "+ $*"
        "$@"
    fi
}

run pmbootstrap checksum linux-motorola-devonf
run pmbootstrap checksum device-motorola-devonf
[[ "$DO_KCONFIG" -eq 0 ]] || run pmbootstrap kconfig check linux-motorola-devonf
[[ "$DO_BUILD" -eq 0 ]] || run pmbootstrap build --force linux-motorola-devonf device-motorola-devonf
[[ "$DO_INSTALL" -eq 0 ]] || run pmbootstrap install

cat <<HINT

Done. Next steps:
  - pmbootstrap init   (pick vendor 'motorola', device 'devonf')
  - Flash with: pmbootstrap flasher flash_rootfs
                pmbootstrap flasher flash_kernel
  - See docs/linux.md for details.
HINT
