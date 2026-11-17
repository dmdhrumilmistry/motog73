# motog73: open source ROM, recovery and Linux for the moto g73 5G

Build configuration, tools and documentation for running **custom Android
(LineageOS + the "G73 Open" flavor)**, a **custom recovery (TWRP)** and
**Linux (postmarketOS)** on the **Motorola moto g73 5G**
(codename `devonf`, MediaTek Dimensity 930 / MT6855).

Built against stock firmware **U1TNS34.82-12-7-26** (Android 14) and
Motorola's matching open source kernel release.

> This repository contains **no proprietary firmware, no signing keys and no
> personal data**. Device-specific files (your stock images, keys, backups)
> stay on your computer in git-ignored folders.

## What's inside

| Path | What it is |
| :--- | :--- |
| [`rom/`](rom) | LineageOS 24.0 local manifest for `devonf`, the G73 Open flavor layer (`vendor/extra`), build and signing-key scripts |
| [`recovery/`](recovery) | TWRP device tree (recovery inside `vendor_boot`, boot header v4) and build script |
| [`kernel/`](kernel) | Kernel build script for Motorola's source, config fragments, `repo` manifest with all out-of-tree modules |
| [`linux/postmarketos/`](linux/postmarketos) | postmarketOS device and kernel packages (pmaports `device/downstream` style) plus import helper |
| [`scripts/`](scripts) | Extract stock images, repack `boot`/`vendor_boot` safely, flash helpers with device checks, restore stock from `flashfile.xml` |
| [`docs/`](docs) | Guides (start below) |

## Quick start

1. **Read [docs/device-info.md](docs/device-info.md)** and confirm your phone is a `devonf`:
   `adb shell getprop ro.product.device`
2. **Unlock the bootloader:** [docs/unlock-bootloader.md](docs/unlock-bootloader.md)
3. Pick what you want:

| Goal | Guide |
| :--- | :--- |
| Install a custom ROM (LineageOS + G73 Open, or a GSI) | [docs/install-rom.md](docs/install-rom.md) |
| Build the ROM yourself | [docs/build-rom.md](docs/build-rom.md) |
| Custom recovery (Lineage Recovery / TWRP / others) | [docs/recovery.md](docs/recovery.md) |
| Build the kernel | [docs/kernel.md](docs/kernel.md) |
| Run Linux (postmarketOS) | [docs/linux.md](docs/linux.md) |
| Go back to stock / unbrick | [docs/restore-stock.md](docs/restore-stock.md) |

## Status

| Component | State |
| :--- | :--- |
| Kernel from source (`MMI-U1TNS34.82-12-7-26`) | Builds with AOSP clang r416183b: `Image.gz`, 618 modules and `mt6855.dtb` (built locally on 2026-11-17). CI build is a manual workflow. |
| LineageOS 24.0 + G73 Open | Build setup on top of the maintained community device tree. Not built by this project yet. |
| TWRP | Device tree plus safe `vendor_boot` injection. Data decryption not supported yet. Not built yet. |
| postmarketOS | Packages follow pmaports `device/downstream` conventions and pass offline checks. Not built with pmbootstrap yet. |
| Helper scripts | Repack, flashfile and package checks tested offline on synthetic data (`tests/run-tests.sh`, runs in CI) |

**Nothing is tested on real hardware yet.** Please report what works with
the [device report template](.github/ISSUE_TEMPLATE/device-report.md).

## Safety

- Every flashing helper checks `fastboot getvar product == devonf` first, and
  asks before writing.
- Custom recovery is injected into **your own stock `vendor_boot`**, so normal
  Android boot is untouched.
- Keep your stock firmware package. `scripts/flash.sh restore` puts the phone
  back to stock using Motorola's own `flashfile.xml`, after checking MD5s.
- Never share backups of `nvram`, `nvdata`, `persist` or `proinfo`. They
  contain your IMEI and calibration data.

You flash at your own risk. See the [license](LICENSE) (no warranty).

## Credits

This project builds on the work of Motorola's open source releases, LineageOS,
TeamWin, postmarketOS and the `devonf` community device maintainers. See
[CREDITS.md](CREDITS.md).

## License

[Apache License 2.0](LICENSE). Third-party sources fetched by the scripts keep
their own licenses (the Linux kernel is GPL-2.0).
