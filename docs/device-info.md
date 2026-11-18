# Device information: moto g73 5G (`devonf`)

Everything on this page comes from public sources: Motorola's kernel release,
the community device tree, and the public spec sheet. You can check the values
yourself (commands below). Nothing here identifies a particular phone.

## Identification

| Item | Value |
| :--- | :--- |
| Marketing name | moto g73 5G |
| Codename | `devonf` (`fastboot getvar product`) |
| Model numbers | XT2237-1, XT2237-2 (region variants) |
| Sibling | moto g power 5G (2023), codename `devonn`. Same SoC and kernel, but a different board. Do **not** cross-flash. |
| Launch OS | Android 13 |
| Target build | `U1TNS34.82-12-7-26` (Android 14, the last major update) |

Check your phone:

```sh
adb shell getprop ro.product.device        # devonf
adb shell getprop ro.build.display.id      # U1TNS34.82-12-7-26 (or similar)
adb shell getprop ro.boot.slot_suffix      # _a or _b
```

## Hardware

| Part | Details |
| :--- | :--- |
| SoC | MediaTek Dimensity 930 (MT6855), 6 nm |
| CPU | 2x Cortex-A78 @ 2.2 GHz + 6x Cortex-A55 @ 2.0 GHz |
| GPU | IMG BXM-8-256 |
| RAM / storage | 8 GB / 128-256 GB UFS 2.2, microSD slot |
| Display | 6.5" 1080x2400 IPS, 120 Hz, Tianma NT36672C panel (`dsi-panel-mot-tianma-nt36672c-649-fhdp-dphy-vdo-120hz`) |
| Touch | Novatek NT36672C (`nova_0flash_mmi_v2`) |
| Cameras | 50 MP OmniVision OV50A (main), 8 MP Samsung S5K4H7 (ultrawide), 16 MP Hynix HI1634Q (front) |
| Charger / PMIC | MT6375 charger + TCPC, MT6363/MT6369 PMICs |
| Battery | 5000 mAh |
| Audio | AW87xxx speaker amplifiers |
| Connectivity | MT6855 combo (Wi-Fi 5, BT 5.3, GNSS, FM), NFC (some regions) |

## Boot and partitions

The g73 uses Android's modern GKI layout:

- **A/B slots with Virtual A/B** (compressed snapshots).
- **No recovery partition.** The recovery ramdisk is a fragment inside
  `vendor_boot`. To install a custom recovery you replace that fragment
  (see [recovery.md](recovery.md)).
- **Boot image header v4.** `boot` holds the kernel and the generic ramdisk.
  `vendor_boot` holds the DTB, the vendor ramdisk (first-stage modules and fstab)
  and the recovery ramdisk. `dtbo` holds the board overlay.
- **Dynamic partitions** in `super`: `system`, `system_ext`, `vendor`,
  `vendor_dlkm`, `product` (erofs). `userdata` is f2fs with FBE v2 plus metadata
  encryption (wrapped keys).

| Partition | Size |
| :--- | :--- |
| `boot_a/b` | 64 MiB |
| `vendor_boot_a/b` | 64 MiB |
| `super` | 5,502,926,848 bytes |
| group `motorola_dynamic_partitions` | 5,498,732,544 bytes |

Boot image parameters (identical for `boot` and `vendor_boot`):

| Parameter | Value |
| :--- | :--- |
| header version | 4 |
| page size | 4096 |
| base | `0x00000000` |
| kernel offset | `0x40000000` |
| ramdisk offset | `0x66f00000` |
| tags / DTB offset | `0x47c80000` |
| cmdline | `bootopt=64S3,32N2,64N2` |
| ramdisk compression | lz4 (legacy) |

You can check these on your own images with
`scripts/extract-stock-images.sh` (it writes `boot-info.txt` and `vendor_boot-info.txt`).

## Kernel

| Item | Value |
| :--- | :--- |
| Version | Linux 5.10.240, GKI `android12-5.10` (merged up to `android12-5.10-2025-09_r6`) |
| Source | [MotorolaMobilityLLC/kernel-mtk](https://github.com/MotorolaMobilityLLC/kernel-mtk) tag `MMI-U1TNS34.82-12-7-26` |
| Config | `gki_defconfig` + `mgk_64_k510_defconfig` + `ext_config/moto-mgk_64_k510.config` + `ext_config/moto-mgk_64_k510-devonf.config` |
| Compiler | AOSP clang r416183b (LLVM 12), `LLVM=1 LLVM_IAS=1` |
| SoC DTB | `arch/arm64/boot/dts/mediatek/mt6855.dts` |
| Board overlay | `mt6855-devonf-*-overlay.dts`. It includes a DCT-generated `cust.dtsi` that is not public, so use the stock `dtbo.img`. |
| Out-of-tree modules | `motorola-kernel-modules` and `vendor-mediatek-kernel_modules-*`, all tagged `MMI-U1TNS34.82-12-7-26` (see `kernel/manifests/`) |
