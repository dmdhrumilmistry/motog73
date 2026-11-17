# Custom recovery for the moto g73 5G

The g73 has **no recovery partition**. Recovery is a ramdisk fragment
(type `RECOVERY`) inside `vendor_boot` (boot header v4). The same image also
holds the DTB and the vendor ramdisk that normal Android needs to boot.

That is why this project never flashes a vendor_boot built from scratch.
[`scripts/repack-vendor-boot.sh`](../scripts/repack-vendor-boot.sh) takes
**your stock `vendor_boot.img`**, keeps every stock fragment, the DTB, the
load addresses and the cmdline byte-for-byte, and swaps in only the recovery
ramdisk. The result:

- Android keeps booting normally.
- "Recovery mode" starts the custom recovery.
- Undoing it means flashing the stock `vendor_boot.img` back.

## Option 1: Lineage Recovery (simplest)

A LineageOS build ([build-rom.md](build-rom.md)) already produces
`vendor_boot.img` with Lineage Recovery. It can sideload ROMs, factory reset,
and run fastbootd. For installing ROMs this is the recommended recovery.

## Option 2: TWRP (backups, file manager, terminal)

The TWRP device tree is in
[`recovery/twrp/device/motorola/devonf`](../recovery/twrp/device/motorola/devonf).

### Build

```sh
# 1. Extract kernel, DTB and vendor modules from YOUR stock firmware
scripts/extract-stock-images.sh ~/Downloads/<stock-firmware>.zip stock/devonf

# 2. Sync TWRP (minimal manifest, twrp-14.1), build, then repack into stock vendor_boot
recovery/build-twrp.sh stock/devonf
# -> out/recovery/twrp-devonf-vendor_boot.img
```

The stock images and prebuilts stay under `stock/` and are git-ignored.
They are never committed.

### Flash

```sh
adb reboot bootloader
scripts/flash.sh recovery out/recovery/twrp-devonf-vendor_boot.img
scripts/flash.sh boot-recovery
```

Or from the powered-off phone: hold **Volume Down + Power**, then choose
**Recovery mode** with the volume keys.

Undo:

```sh
fastboot flash vendor_boot_<slot> stock/devonf/images/vendor_boot.img
```

### Status

| Feature | Status |
| :--- | :--- |
| Boots, display, touch | Expected to work: uses the stock kernel and touch module from vendor_boot |
| ADB, sideload, fastbootd | Expected to work |
| Flashing images (boot/vendor_boot/dtbo/logo) | Expected to work |
| Backup/restore of partitions (incl. NVRAM, nvdata, persist) | Expected to work. **Keep these backups private:** they contain the IMEI and calibration data. |
| microSD / MTP | Expected to work |
| /data decryption | **Not working yet.** It needs MediaTek/Trustonic keymint blobs, which are proprietary and not shipped here. |
| Slot switching from TWRP | Not supported (MediaTek boot-control HAL is proprietary). Use `fastboot set_active a\|b`. |

"Expected to work" means the configuration follows the stock layout but has
not yet been confirmed on hardware by this project. Please report results
with the issue template.

## Option 3: Any other recovery (OrangeFox, …)

Any recovery that builds a `RECOVERY`-type vendor ramdisk fragment can be
injected the same way:

```sh
scripts/repack-vendor-boot.sh \
    -s stock/devonf/images/vendor_boot.img \
    -r <recovery-vendor_boot.img or ramdisk.cpio.lz4> \
    -o out/recovery/custom-vendor_boot.img
```

OrangeFox can reuse the TWRP device tree here (add its `FOX_*` variables to
`BoardConfig.mk`).
