#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Prepare a GitHub-hosted Ubuntu runner for a large build.
#
# Usage: prepare-runner.sh [--free-disk] [--swap GB] [--swap-file PATH] [--workdir DIR]
#
#   --free-disk        remove preinstalled toolchains this project does not need
#   --swap GB          replace swap with a GB-gigabyte swap file
#   --swap-file PATH   where to put the swap file (default /mnt/swapfile)
#   --zram GB          use a GB-gigabyte compressed RAM swap (zram) instead of a
#                      swap file. Hosted runners keep / and /mnt on one
#                      device-mapper copy-on-write volume, and swapping onto it
#                      under memory pressure can hang the VM (the runner then
#                      dies without logs). zram avoids the disk entirely.
#   --workdir DIR      create DIR on the big disk, owned by the current user
#
set -euo pipefail

FREE_DISK=0
SWAP_GB=""
SWAP_FILE="/mnt/swapfile"
ZRAM_GB=""
WORKDIR=""

usage() {
    echo "Usage: $(basename "$0") [--free-disk] [--swap GB] [--swap-file PATH] [--zram GB] [--workdir DIR]"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --free-disk) FREE_DISK=1 ;;
        --swap)
            [ $# -ge 2 ] || { usage >&2; exit 2; }
            SWAP_GB="$2"; shift ;;
        --zram)
            [ $# -ge 2 ] || { usage >&2; exit 2; }
            ZRAM_GB="$2"; shift ;;
        --swap-file)
            [ $# -ge 2 ] || { usage >&2; exit 2; }
            SWAP_FILE="$2"; shift ;;
        --workdir)
            [ $# -ge 2 ] || { usage >&2; exit 2; }
            WORKDIR="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
    shift
done

if [ "$FREE_DISK" -eq 1 ]; then
    sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc \
        /usr/local/.ghcup /opt/hostedtoolcache/CodeQL /usr/share/swift
    docker image prune -af || true
fi

if [ -n "$SWAP_GB" ]; then
    sudo swapoff -a
    sudo rm -f /mnt/swapfile "$SWAP_FILE"
    sudo fallocate -l "${SWAP_GB}G" "$SWAP_FILE"
    sudo chmod 600 "$SWAP_FILE"
    sudo mkswap "$SWAP_FILE"
    sudo swapon "$SWAP_FILE"
fi

if [ -n "$ZRAM_GB" ]; then
    sudo swapoff -a
    sudo rm -f /mnt/swapfile
    if ! sudo modprobe zram 2>/dev/null; then
        sudo apt-get install -y -q "linux-modules-extra-$(uname -r)" >/dev/null
        sudo modprobe zram
    fi
    dev="$(sudo zramctl --find --size "${ZRAM_GB}G" --algorithm zstd 2>/dev/null \
           || sudo zramctl --find --size "${ZRAM_GB}G" --algorithm lz4)"
    sudo mkswap "$dev"
    sudo swapon --priority 100 "$dev"
    # Swap eagerly to compressed RAM rather than thrashing the page cache.
    sudo sysctl -q vm.swappiness=180 vm.page-cluster=0 || sudo sysctl -q vm.swappiness=100
fi

if [ -n "$WORKDIR" ]; then
    sudo mkdir -p "$WORKDIR"
    sudo chown "$USER:" "$WORKDIR"
fi

df -h / /mnt
free -h
swapon --show || true
