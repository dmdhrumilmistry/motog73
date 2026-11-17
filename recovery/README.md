# recovery/

TWRP for the moto g73 5G (`devonf`). Recovery lives inside `vendor_boot`
(there is no recovery partition), so the build output is injected into your
**stock** `vendor_boot.img` with `scripts/repack-vendor-boot.sh`.

```sh
scripts/extract-stock-images.sh <stock-firmware.zip> stock/devonf
recovery/build-twrp.sh stock/devonf          # twrp-14.1 minimal manifest
scripts/flash.sh recovery out/recovery/twrp-devonf-vendor_boot.img
```

The tree in `twrp/device/motorola/devonf` is copied to
`<twrp-source>/device/motorola/devonf`. Kernel, DTB and vendor modules come
from your stock images (`prebuilt/`, git-ignored).

Guide and status: [docs/recovery.md](../docs/recovery.md).
