# Building LineageOS + G73 Open

## What gets built

- **LineageOS 24.0**, unmodified, from LineageOS' own repositories.
- **Device support for `devonf`** from the community LineageOS-based trees
  (device, prebuilt kernel, vendor blobs, MediaTek HALs). The exact
  repositories and branches are pinned in
  [`rom/local_manifests/devonf.xml`](../rom/local_manifests/devonf.xml).
- **The G73 Open flavor** ([`rom/vendor/extra`](../rom/vendor/extra)), a
  small, auditable layer on top. LineageOS loads `vendor/extra/product.mk`
  on its own, so no repository needs to be forked. It adds:
  - a version tag: `lineage-24.0-<date>-UNOFFICIAL-g73open-devonf`,
  - `ro.g73open.version`,
  - privacy defaults through a runtime resource overlay (time sync uses
    `pool.ntp.org` instead of a single vendor's NTP server).

Turn the flavor off with `WITH_FLAVOR=0` to build plain LineageOS.

## Requirements

- Linux x86_64 host (Ubuntu 22.04+/Debian 12+ recommended)
- 400 GB free disk (SSD), 32 GB RAM or more (16 GB works with 32 GB of swap/zram)
- `repo`, `git`, `git-lfs`, plus the
  [LineageOS build packages](https://wiki.lineageos.org/emulator#install-the-build-packages)

```sh
sudo apt install bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev libelf-dev \
  liblz4-tool libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync \
  schedtool squashfs-tools xsltproc zip zlib1g-dev python3 repo
```

## Build

```sh
git clone https://github.com/dmdhrumilmistry/motog73
cd motog73

rom/build-rom.sh sync          # repo init + sync LineageOS and devonf repos (~150 GB)
rom/gen-keys.sh                # once: create YOUR private signing keys
rom/build-rom.sh build         # builds lineage_devonf (userdebug by default)
```

Useful variables:

```sh
VARIANT=user rom/build-rom.sh build              # user build
LINEAGE_DIR=/mnt/fast/lineage rom/build-rom.sh   # different source location
WITH_FLAVOR=0 rom/build-rom.sh build             # plain LineageOS
export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache  # faster rebuilds
```

## Signing

`rom/gen-keys.sh` creates keys in `<source>/vendor/lineage-priv/keys`.
LineageOS uses them automatically. Some notes:

- **Never commit or publish them.** Anyone holding them can sign updates
  your phone will accept. The repository `.gitignore` also blocks key files.
- Back them up privately. Builds signed with different keys can't be installed
  over each other without wiping data.
- The upstream community tree references its maintainer's private key
  repository. This project **does not** include it.

## Updating

```sh
rom/build-rom.sh sync && rom/build-rom.sh build
```

To pick up newer device trees, update the branches in
`rom/local_manifests/devonf.xml`, then sync again.

## Troubleshooting

- **`lunch` fails: product not found.** Run `sync` again and check that
  `device/motorola/devonf` exists.
- **Out of memory in metalava/R8/soong.** Use fewer jobs (`JOBS=4`) and add swap.
- **Missing proprietary files.** The vendor repositories are maintained by
  the community. If a blob is missing after a device-tree update, check the
  device tree's `proprietary-files.txt` and update the vendor branch.
- **ImsService / MtkGbaService.** The device tree ships patches for these in
  `device/motorola/devonf/patches/`. Apply them if VoLTE-related builds fail.
