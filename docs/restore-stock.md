# Restoring stock firmware

Download the official fastboot firmware for **your exact model and region**
(for example the U1TNS34.82-12-7-26 package for XT2237-x). Get it from
Motorola's Rescue and Smart Assistant (RSA), or from a trusted mirror that
publishes Motorola's original packages with their MD5 checksums. Extract it
to a folder.

## Using this repository's helper

[`scripts/moto-flashfile.py`](../scripts/moto-flashfile.py) reads the
package's own `flashfile.xml`, verifies the MD5 of every image, and runs the
same fastboot steps Motorola's tools run.

```sh
adb reboot bootloader
scripts/flash.sh check

# Dry run: print the commands only
scripts/flash.sh restore ~/firmware/XT2237-2_DEVONF_...

# Flash, wiping data (recommended when coming back from a custom ROM)
scripts/flash.sh restore ~/firmware/XT2237-2_DEVONF_... --execute

# Flash, keeping data (same or newer stock build only)
scripts/flash.sh restore ~/firmware/XT2237-2_DEVONF_... --execute --keep-data
```

The script refuses to run unless the connected device reports
`product=devonf`.

## Using Motorola's tool

Motorola's **Rescue and Smart Assistant** (Windows) can also repair the
phone ("Rescue" mode). It works with unlocked bootloaders too.

## Hard-bricked? (no fastboot)

If the phone shows nothing and only enumerates as a MediaTek preloader/BROM
USB device, the open source [mtkclient](https://github.com/bkerler/mtkclient)
can still read and write partitions. Only use it as a last resort and only
with images from your own device or official firmware. Never write another
phone's `nvram`/`nvdata`/`proinfo`.
