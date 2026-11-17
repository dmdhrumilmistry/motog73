# rom/

LineageOS 24.0 + the **G73 Open** flavor for the moto g73 5G (`devonf`).

| File | Purpose |
| :--- | :--- |
| `local_manifests/devonf.xml` | Device, kernel, vendor and MediaTek repositories (pinned branches) |
| `vendor/extra/` | G73 Open flavor, installed as `vendor/extra` (LineageOS loads it automatically) |
| `build-rom.sh` | `sync`, `build` or `all` |
| `gen-keys.sh` | Creates your private signing keys inside the source tree (never commit them) |

Guide: [docs/build-rom.md](../docs/build-rom.md). Installing: [docs/install-rom.md](../docs/install-rom.md).
