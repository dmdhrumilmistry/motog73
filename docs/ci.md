# CI, builds and releases

Workflows live in [`.github/workflows/`](../.github/workflows). None of the
build outputs have been tested on hardware, and no release has been published
yet.

## Workflows

| Workflow | Trigger | Runtime | Output |
| :--- | :--- | :--- | :--- |
| `ci.yml` | push to `main`, pull requests | minutes | Lint only: actionlint, shellcheck, XML, Python syntax, no-blobs check, offline tests |
| `kernel.yml` | manual dispatch, reusable | about 2.5 to 3.5 h | Artifact `devonf-kernel`: `devonf-kernel-Image.gz`, `devonf-kernel-mt6855.dtb`, `devonf-kernel-modules.tar.xz`, `devonf-kernel-config`, `devonf-kernel.release` |
| `twrp.yml` | manual dispatch, reusable | long (builds the kernel too) | Artifact `devonf-twrp`: `devonf-twrp-recovery-ramdisk.cpio.lz4`, `devonf-twrp-vendor_boot-raw-DO-NOT-FLASH.img` |
| `postmarketos.yml` | manual dispatch, reusable | long | Artifact `devonf-pmos`: kernel and device apks, `devonf-pmos-<ui>-rootfs.img.xz`, `devonf-pmos-boot.img`, possibly `devonf-pmos-vendor_boot.img`. Artifact `devonf-pmos-meta`: APKBUILD with the real tarball checksum, for maintainers |
| `build.yml` | pull requests (see below), manual dispatch | all of the above | Build only: workflow artifacts, never a release |
| `release.yml` | tag push `v*`, manual dispatch with `release_tag` | all of the above | Prerelease (tag) or draft release (dispatch) with all assets |
| `rom.yml` | manual dispatch | many hours | LineageOS artifact, self-hosted runner only, never released |

Details:

- **kernel**: Motorola kernel built with AOSP clang r416183b on ubuntu-24.04.
  If the LTO link runs out of memory it is retried with `-j1`.
- **twrp**: TWRP `twrp-14.1` minimal manifest, built against the CI kernel and
  the DTB built from source. No stock files are used. The raw `vendor_boot`
  image in the artifact lacks the stock vendor ramdisk and must never be
  flashed; see [recovery.md](recovery.md).
- **postmarketos**: pmbootstrap 3.12.1 runs
  `linux/postmarketos/ci-build.sh <ui> <outdir>` (non-interactive init,
  `pmaports-import.sh`, build, install, export). Default UI is `console`.
  The image has a default login (`user` / `147147`) that you must change.
- **rom**: see the self-hosted runner section below.

## Runner disk and swap

GitHub runners have little free space on `/`, so the big jobs use `/mnt`
(the larger temporary disk) for work directories and swap files:

| Job | Work dir | Swap on `/mnt` |
| :--- | :--- | :--- |
| kernel | `/mnt` | 20 GB |
| TWRP | `/mnt` | 12 GB |
| postmarketOS | `/mnt` | 8 GB |

## Cutting a release

```sh
git tag v0.1.0
git push origin v0.1.0
```

This builds everything and creates a **prerelease** with all assets, a
`SHA256SUMS` file and release notes. For a **draft** release without a tag,
open Actions, pick "Release", click "Run workflow" and enter a
`release_tag`. Review the draft, then publish it by hand.

## What runs on pull requests

`build.yml` runs on pull requests that touch `.github/**`, `kernel/**`,
`recovery/**`, `linux/postmarketos/**` or `scripts/repack-vendor-boot.sh`.
The kernel is always built. TWRP and postmarketOS are built only when their
own paths change. It has no release step, so pull requests never publish
anything. To build without releasing, run "Build" from the Actions tab.

## Minutes

Public repositories get free, unlimited minutes on standard runners. Private
repositories have a limited free quota, and one full PR or release run is
roughly 8 to 10 runner-hours, so check your quota first.

## Self-hosted runner for LineageOS

`rom.yml` takes a `runner` input (default `["self-hosted","lineage"]`). A
preflight step fails the run unless the machine has at least 32 GiB of RAM plus
swap, 300 GiB of free disk and 8 cores. Outline:

1. Use a Linux x86_64 machine that meets the numbers above.
2. In the repository settings, add a new self-hosted runner and register it
   with the labels `self-hosted,lineage`. Run it as a normal user, not root.
3. Install the AOSP build dependencies and `repo`
   (see [build-rom.md](build-rom.md)).
4. Run `rom/gen-keys.sh` once on the runner. The signing keys stay on that
   machine and are never uploaded; back them up privately.
5. Start the "rom" workflow from the Actions tab.

Use self-hosted runners only on private repositories, or on public ones whose
pull request workflows from forks cannot run on that machine.

ROM output is kept as a workflow artifact only. It is not attached to
releases because ROM builds contain community vendor blobs.
