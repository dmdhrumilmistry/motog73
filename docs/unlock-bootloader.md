# Unlocking the bootloader

Everything else in this project needs an unlocked bootloader.

> **Warning:** Unlocking **erases all data** on the phone. It may affect your
> warranty depending on your region. Some carrier-locked units cannot be
> unlocked at all. Back up first.

## 1. Prepare the phone

1. Settings → About phone → tap **Build number** 7 times to enable Developer options.
2. Settings → System → Developer options:
   - enable **OEM unlocking** (needs an internet connection; it can stay greyed
     out for a few days on new phones),
   - enable **USB debugging**.
3. Install the Android platform tools (`adb`, `fastboot`) on your computer.

## 2. Get the unlock code

```sh
adb reboot bootloader
fastboot oem get_unlock_data
```

Join the output lines into one string (no spaces, drop the `(bootloader)`
prefixes) and submit it on Motorola's official bootloader unlock page
(reachable from motorola.com, search "unlock bootloader"). Motorola emails
the unlock key to the address on your Motorola account.

Keep the unlock data and key private. They are tied to your phone.

## 3. Unlock

```sh
fastboot oem unlock <UNIQUE_KEY>
fastboot oem unlock <UNIQUE_KEY>   # Motorola asks you to repeat it to confirm
```

Confirm on the phone with the volume keys. It wipes itself and reboots.
Check the result:

```sh
scripts/flash.sh check        # unlocked: yes
```

## Relocking

Only relock **after** going back to unmodified stock firmware
([restore-stock.md](restore-stock.md)). Relocking with custom images
installed can leave the phone unbootable.

```sh
fastboot oem lock
```
