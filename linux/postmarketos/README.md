# postmarketOS packages for the moto g73 5G

- `device-motorola-devonf/`: deviceinfo + initramfs modules
- `linux-motorola-devonf/`: kernel package (Motorola source, postmarketOS config)

`config-motorola-devonf.aarch64` is generated with:

```sh
kernel/build-kernel.sh -p -k -c src/clang-r416183b
cp out/kernel/.config linux/postmarketos/linux-motorola-devonf/config-motorola-devonf.aarch64
```

After changing a file, refresh checksums with `pmbootstrap checksum <package>`.

Guide: [docs/linux.md](../../docs/linux.md).
