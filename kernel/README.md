# kernel/

| File | Purpose |
| :--- | :--- |
| `build-kernel.sh` | Clone + configure + build Motorola's kernel (`Image.gz`, `mt6855.dtb`, modules) |
| `fetch-clang.sh` | Download AOSP clang r416183b, the compiler this kernel targets |
| `configs/g73open.config` | Small fragment for the ROM flavor (KMI-safe) |
| `configs/postmarketos.config` | Options needed by a regular Linux userspace |
| `configs/no-werror.config` | Lets newer clang releases build the tree (`-W`) |
| `manifests/devonf-U1TNS34.82-12-7-26.xml` | `repo` manifest: kernel + all out-of-tree module repos at the same tag |

Guide: [docs/kernel.md](../docs/kernel.md).
