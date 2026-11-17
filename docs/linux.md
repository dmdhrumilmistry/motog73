# Linux on the moto g73 5G (postmarketOS port)

This is a **bring-up port** of [postmarketOS](https://postmarketos.org)
(Alpine-based mobile Linux). It runs a regular GNU/Linux userspace (Phosh,
Plasma Mobile, SXMO or console-only) on Motorola's own 5.10 kernel.

The packages are in [`linux/postmarketos`](../linux/postmarketos):

| Package | Contents |
| :--- | :--- |
| `linux-motorola-devonf` | Kernel from Motorola's source tag `MMI-U1TNS34.82-12-7-26` with [`kernel/configs/postmarketos.config`](../kernel/configs/postmarketos.config) merged in. Also builds the SoC DTB `mediatek/mt6855.dtb` from source. |
| `device-motorola-devonf` | `deviceinfo` (boot header v4 layout, flash offsets, partitions) and the initramfs module list. |

## Expected status

On a downstream MediaTek GKI kernel, the realistic first milestones are:

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
PMAPORTS="$(pmbootstrap config aports)"

# Add the packages from this repository
mkdir -p "$PMAPORTS/device/testing"
cp -r linux/postmarketos/device-motorola-devonf "$PMAPORTS/device/testing/"
cp -r linux/postmarketos/linux-motorola-devonf  "$PMAPORTS/device/testing/"
pmbootstrap checksum linux-motorola-devonf     # fills the source tarball checksum

pmbootstrap init                      # vendor: motorola, device: devonf, UI: e.g. console or phosh
pmbootstrap install                   # builds the kernel (needs ~30 GB and time)

adb reboot bootloader
scripts/flash.sh check
pmbootstrap flasher flash_rootfs      # writes the rootfs to userdata (wipes Android data)
pmbootstrap flasher flash_kernel      # writes boot + vendor_boot for the active slot
fastboot reboot
```

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

- The kernel is built with the distribution's clang. MediaTek's drivers
  enable `-Werror`, so the APKBUILD downgrades the extra warnings that newer
  clang releases emit (`_kcflags`).
- The board overlay (`dtbo`) stays stock. Only the base SoC DTB goes into
  the generated `vendor_boot`.
- ThinLTO is enabled instead of full LTO to keep build RAM reasonable. CFI
  stays on, matching GKI.
- Debug the initramfs with `PMOS_NO_OUTPUT_REDIRECT` (set in the cmdline) and
  the [pmOS initramfs debug shell](https://wiki.postmarketos.org/wiki/Inspecting_the_initramfs).
