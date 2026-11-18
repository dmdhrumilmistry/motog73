# postmarketOS packages for the moto g73 5G

All untested on hardware.

- `device-motorola-devonf/`: `deviceinfo`, `kernel-cmdline.conf`, initramfs modules
- `linux-motorola-devonf/`: kernel package (Motorola source, postmarketOS config)
- `pmaports-import.sh`: copies both packages into a pmaports checkout
  (`device/downstream`), updates checksums, optionally builds/installs

`config-motorola-devonf.aarch64` is generated with:

```sh
kernel/build-kernel.sh -p -k -c src/clang-r416183b
cp out/kernel/.config linux/postmarketos/linux-motorola-devonf/config-motorola-devonf.aarch64
```

After changing a file, refresh checksums with `pmbootstrap checksum <package>`.

Guide: [docs/linux.md](../../docs/linux.md).
