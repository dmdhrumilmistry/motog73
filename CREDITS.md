# Credits

This project is configuration and tooling. The heavy lifting is done by these
projects and people:

- **Motorola Mobility**: open source kernel and module releases
  ([MotorolaMobilityLLC](https://github.com/MotorolaMobilityLLC)).
- **LineageOS**: the Android distribution this ROM is built on.
- **devonf community maintainers**: the LineageOS-based device tree, prebuilt
  kernel and vendor trees for the moto g73 5G. Repositories, all referenced
  (not copied) by `rom/local_manifests/devonf.xml`:
  - [MistOS-Devices/device_motorola_devonf](https://github.com/MistOS-Devices/device_motorola_devonf)
    (originally based on work by the ArrowOS and PixelOS teams)
  - [kjdev16](https://github.com/kjdev16): vendor, kernel, `hardware_mediatek` and HAL forks
  - [sreejith7676](https://github.com/sreejith7676): Moto camera vendor tree
  - [YAAP](https://github.com/yaap): `device_mediatek_sepolicy_vndr`
- **TeamWin (TWRP)** and the minimal-manifest-twrp maintainers.
- **postmarketOS**: pmbootstrap, packaging conventions and device porting docs.
- **AOSP**: `mkbootimg` / `unpack_bootimg`, used by the repack scripts.
- **bkerler/mtkclient**: MediaTek recovery tooling referenced in the docs.

If you maintain one of these repositories and want the reference changed,
please open an issue.
