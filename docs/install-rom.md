# Installing a custom ROM

There are two ways to replace stock Android on the g73. Both need an
[unlocked bootloader](unlock-bootloader.md).

| Option | Effort | Result |
| :--- | :--- | :--- |
| **A. LineageOS + G73 Open** (built from this repo) | High: you build it yourself | Full device support: camera, VoLTE, sensors, OTA updates |
| **B. GSI** (Generic System Image) | Low: download and flash | Quick try-out. Some hardware features may not work. |

Before you start, for either option:

- Update the phone to the latest stock build, **U1TNS34.82-12-7-26**. The
  community device tree uses its firmware (modem, TEE, preloader). Firmware is
  stored per slot, so flash stock to **both** slots first: flash the full stock
  package, run `fastboot set_active other`, and flash it again.
- Keep the full stock firmware package for your model. It is your way back
  ([restore-stock.md](restore-stock.md)).
- Back up your data. Installing wipes `userdata`.

## A. LineageOS + G73 Open

Build it as described in [build-rom.md](build-rom.md). The build output
(`$OUT`) contains:

- `lineage-24.0-<date>-UNOFFICIAL-g73open-devonf.zip`: the ROM
- `boot.img`, `vendor_boot.img` (includes Lineage Recovery), `dtbo.img`

Install:

```sh
adb reboot bootloader
scripts/flash.sh check

# 1. Flash the ROM's boot images (vendor_boot contains its recovery)
fastboot flash boot boot.img
fastboot flash vendor_boot vendor_boot.img
fastboot flash dtbo dtbo.img
fastboot reboot recovery

# 2. In Lineage Recovery: Factory reset -> Format data / factory reset
# 3. Apply update -> Apply from ADB, then on the computer:
adb sideload lineage-24.0-*-UNOFFICIAL-g73open-devonf.zip
```

Reboot. The first boot takes a few minutes.

**Google apps (optional):** to add a GApps package, sideload it right after
the ROM, *before* the first boot. When the recovery asks to "reboot to
recovery", say yes so the package installs onto the new slot.

**Updates:** build a newer zip and `adb sideload` it from recovery.
Your data is kept, as long as you sign every build with the same keys
([build-rom.md](build-rom.md#signing)).

## B. GSI (quick try-out)

The g73 is Treble-compliant (launched with Android 13, `arm64` A/B,
`binder64`). Use an **arm64 / bvN / ab** GSI built for Android 14 or newer,
for example a TrebleDroid-based build.

```sh
adb reboot bootloader
scripts/flash.sh gsi system-arm64-ab.img     # moves to fastbootd, flashes, wipes data
fastboot reboot
```

Known GSI caveats on MediaTek devices: VoLTE/IMS, the camera's auxiliary
lenses and some sensors often don't work. Use the "Phh Treble settings" app
that TrebleDroid builds include to toggle MediaTek workarounds.

Going back to stock: [restore-stock.md](restore-stock.md).
