# scripts/

| Script | Purpose |
| :--- | :--- |
| `fetch-tools.sh` | Fetch AOSP `mkbootimg`/`unpack_bootimg` into `src/tools` |
| `extract-stock-images.sh` | Pull boot/vendor_boot/dtbo/vbmeta out of YOUR stock firmware and unpack them (output is git-ignored) |
| `repack-vendor-boot.sh` | Inject a recovery ramdisk into the stock `vendor_boot`, keeping everything else |
| `repack-boot.sh` | Put a custom kernel into the stock `boot.img` |
| `flash.sh` | fastboot helpers with a `devonf` device check and confirmations |
| `moto-flashfile.py` | Restore stock from Motorola's `flashfile.xml` (MD5-verified, dry run by default) |

Offline tests: `tests/run-tests.sh`.
