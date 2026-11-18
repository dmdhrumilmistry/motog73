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
#   --swap-file PATH   where to put the swap file (default /mnt/swapfile); use a
#                      path on / when /mnt is needed for sources
#   --workdir DIR      create DIR on the big disk, owned by the current user
#
set -euo pipefail

FREE_DISK=0
SWAP_GB=""
SWAP_FILE="/mnt/swapfile"
WORKDIR=""

usage() {
    echo "Usage: $(basename "$0") [--free-disk] [--swap GB] [--swap-file PATH] [--workdir DIR]"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --free-disk) FREE_DISK=1 ;;
        --swap)
            [ $# -ge 2 ] || { usage >&2; exit 2; }
            SWAP_GB="$2"; shift ;;
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

if [ -n "$WORKDIR" ]; then
    sudo mkdir -p "$WORKDIR"
    sudo chown "$USER:" "$WORKDIR"
fi

df -h / /mnt
free -h
