# Linux on the moto g73 5G (postmarketOS port)

This is a **bring-up port** of [postmarketOS](https://postmarketos.org)
(Alpine-based mobile Linux). It runs a regular GNU/Linux userspace (Phosh,
Plasma Mobile, SXMO or console-only) on Motorola's own 5.10 kernel.

**Nothing here has been tested on real hardware.** Everything below describes
intent, not verified behavior.

The packages are in [`linux/postmarketos`](../linux/postmarketos):

| Package | Contents |
| :--- | :--- |
| `linux-motorola-devonf` | Kernel from Motorola's source tag `MMI-U1TNS34.82-12-7-26` with [`kernel/configs/postmarketos.config`](../kernel/configs/postmarketos.config) merged in. Also builds the SoC DTB `mediatek/mt6855.dtb` from source. |
| `device-motorola-devonf` | `deviceinfo` (boot header v4 layout, flash offsets, partitions), `kernel-cmdline.conf` and the initramfs module list. |

## Expected status

All untested on hardware. On a downstream MediaTek GKI kernel, the realistic
first milestones would be:

| Feature | Expectation |
| :--- | :--- |
| Boot to initramfs, USB networking (SSH over USB) | First target |
| Display (framebuffer/DRM via MediaTek DRM + panel module) | Likely |
| Touchscreen | Needs the out-of-tree Novatek module (`motorola-kernel-modules`) |
| Storage (UFS), microSD, battery/charging info | Likely (in-tree drivers) |
| Wi-Fi / Bluetooth | Needs the out-of-tree `connectivity` modules plus firmware from the stock vendor partition |
| GPU acceleration | No. The IMG BXM GPU has no open source userspace driver for this kernel; rendering is done in software. |
| Modem, camera, audio | No. These need proprietary Android HALs. A libhybris-based distribution (Droidian/Halium) would be the route. |

## Build and flash

You need [pmbootstrap](https://wiki.postmarketos.org/wiki/Pmbootstrap) and an
[unlocked bootloader](unlock-bootloader.md).

```sh
pmbootstrap init                      # pick any device for now, e.g. qemu-aarch64

# Copy both packages into your pmaports checkout and update checksums
linux/postmarketos/pmaports-import.sh --build

pmbootstrap init                      # vendor: motorola, device: devonf, UI: e.g. console or phosh
pmbootstrap install                   # builds the kernel if needed (needs ~30 GB and time)

adb reboot bootloader
scripts/flash.sh check
pmbootstrap flasher flash_rootfs      # writes the rootfs to userdata (wipes Android data)
pmbootstrap flasher flash_kernel      # writes boot + vendor_boot for the active slot
fastboot reboot
```

Usage of the helper:

```
pmaports-import.sh [--pmaports DIR] [--category downstream] [--force] [--dry-run] [--build] [--install] [--kconfig-check]
```

It copies both package directories into the pmaports checkout (default `DIR`
from `pmbootstrap config aports`), runs `pmbootstrap checksum` for both
packages, and optionally runs the kconfig check, builds, or installs. Use
`--dry-run` first to see what it would do.

Manual alternative:

```sh
PMAPORTS="$(pmbootstrap config aports)"
mkdir -p "$PMAPORTS/device/downstream"
cp -r linux/postmarketos/device-motorola-devonf "$PMAPORTS/device/downstream/"
cp -r linux/postmarketos/linux-motorola-devonf  "$PMAPORTS/device/downstream/"
pmbootstrap checksum device-motorola-devonf linux-motorola-devonf
```

Packages belong in the `device/downstream` category (vendor/downstream
kernels), not `device/testing`.

Then connect over USB networking:

```sh
ssh user@172.16.42.1
```

## Going back to Android

Flash the stock images back (or the full firmware, see
[restore-stock.md](restore-stock.md)):

```sh
fastboot flash boot stock/devonf/images/boot.img
fastboot flash vendor_boot stock/devonf/images/vendor_boot.img
fastboot -w
```

## Notes for porters

- The kernel package uses pmaports' `downstreamkernel_prepare` (which strips
  `-Werror` from the kernel Makefiles, so newer clang warnings do not break
  MediaTek drivers) and `downstreamkernel_package`. It is built with the
  distro clang (`LLVM=1`).
- `postmarketos.config` disables `CONFIG_WERROR`, LTO (`CONFIG_LTO_NONE`) and
  `CFI_CLANG`. That is acceptable because postmarketOS does not load the stock
  GKI vendor modules.
- The kernel command line lives in `kernel-cmdline.conf`, the pmaports
  convention, instead of `deviceinfo_kernel_cmdline`. Obsolete deviceinfo keys
  were removed.
- The SoC DTB `mediatek/mt6855.dtb` is built from source. The board overlay
  (`dtbo` partition) stays stock.
- There is no `soc-*` package: pmaports has nothing reusable for MT6855 (no
  `soc-mediatek-mt6855`, no Motorola MediaTek device).
- There is no firmware package, since this repository ships no proprietary
  blobs. A future one could follow `firmware-motorola-dubai`, pointing at a
  separate repository.
- Debug the initramfs with `PMOS_NO_OUTPUT_REDIRECT` (set in the cmdline) and
  the [pmOS initramfs debug shell](https://wiki.postmarketos.org/wiki/Inspecting_the_initramfs).

## Upstreaming to pmaports

- [ ] The port boots on real hardware first.
- [ ] Set `maintainer=` in both APKBUILDs.
- [ ] `pmbootstrap checksum device-motorola-devonf linux-motorola-devonf`
- [ ] `pmbootstrap lint`
- [ ] Lint `deviceinfo` with `dint`.
- [ ] Commit subject `motorola-devonf: new device`, following pmaports
      `docs/merge-requests/commitstyle.md` ("manufacturer-codename: new
      device").
- [ ] Open a merge request on <https://gitlab.postmarketos.org/postmarketOS/pmaports>.
