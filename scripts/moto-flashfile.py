#!/usr/bin/env python3
#
# SPDX-License-Identifier: Apache-2.0
#
"""Restore stock firmware on a Motorola device from its flashfile.xml.

Motorola fastboot firmware packages ship a flashfile.xml describing the exact
fastboot steps needed to return to stock. This tool reads that file, checks
every image's MD5 checksum, and prints (default) or runs (--execute) the
fastboot commands.

Usage:
    moto-flashfile.py <extracted-firmware-dir> [--execute] [--keep-data]
                      [--serial SERIAL]

--keep-data skips the steps that erase userdata/metadata, so personal data is
kept when re-flashing the same or a newer build. Use the full wipe when
coming back from a custom ROM.
"""

import argparse
import hashlib
import shlex
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

EXPECTED_PRODUCT = "devonf"
DATA_PARTITIONS = {"userdata", "metadata"}
# Steps that only make sense on Motorola's factory tooling.
SKIP_OEM = {"config"}


def md5sum(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_steps(firmware: Path):
    flashfile = firmware / "flashfile.xml"
    if not flashfile.is_file():
        sys.exit(f"error: {flashfile} not found")
    root = ET.parse(flashfile).getroot()
    header = root.find("header")
    phone = header.find("phone_model") if header is not None else None
    model = phone.get("model") if phone is not None else "unknown"
    steps = root.find("steps")
    if steps is None:
        sys.exit("error: flashfile.xml has no <steps>")
    return model, list(steps.findall("step"))


def build_commands(firmware: Path, steps, keep_data: bool):
    commands = []
    for step in steps:
        op = step.get("operation")
        if op == "flash":
            partition = step.get("partition")
            filename = step.get("filename")
            if not partition or not filename:
                sys.exit(f"error: malformed flash step: {step.attrib}")
            image = firmware / filename
            if not image.is_file():
                sys.exit(f"error: missing image {image}")
            expected = (step.get("MD5") or "").lower()
            if expected:
                actual = md5sum(image)
                if actual != expected:
                    sys.exit(f"error: MD5 mismatch for {filename}: {actual} != {expected}")
            commands.append(["flash", partition, str(image)])
        elif op == "erase":
            partition = step.get("partition")
            if keep_data and partition in DATA_PARTITIONS:
                continue
            commands.append(["erase", partition])
        elif op == "oem":
            var = step.get("var")
            if var in SKIP_OEM:
                continue
            commands.append(["oem", var])
        elif op == "getvar":
            commands.append(["getvar", step.get("var")])
        else:
            print(f"warning: skipping unknown operation {op!r}", file=sys.stderr)
    return commands


def fastboot(serial, args, check=True):
    cmd = ["fastboot"] + (["-s", serial] if serial else []) + args
    print("$ " + " ".join(shlex.quote(c) for c in cmd), flush=True)
    return subprocess.run(cmd, check=check, capture_output=False)


def connected_product(serial):
    cmd = ["fastboot"] + (["-s", serial] if serial else []) + ["getvar", "product"]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    for line in (result.stderr + result.stdout).splitlines():
        if line.startswith("product:"):
            return line.split(":", 1)[1].strip()
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("firmware", type=Path, help="extracted stock firmware directory")
    parser.add_argument("--execute", action="store_true", help="run the commands (default: dry run)")
    parser.add_argument("--keep-data", action="store_true", help="do not erase userdata/metadata")
    parser.add_argument("--serial", help="fastboot serial, if more than one device is connected")
    args = parser.parse_args()

    firmware = args.firmware.resolve()
    model, steps = load_steps(firmware)
    print(f"Firmware model: {model}")
    print("Verifying image checksums...")
    commands = build_commands(firmware, steps, args.keep_data)

    if not args.execute:
        print("\nDry run. Commands that would be executed:\n")
        for c in commands:
            print("  fastboot " + " ".join(shlex.quote(x) for x in c))
        print("\nRe-run with --execute to flash.")
        return

    product = connected_product(args.serial)
    if product != EXPECTED_PRODUCT:
        sys.exit(f"error: connected device reports product={product!r}, expected {EXPECTED_PRODUCT!r}")

    for c in commands:
        fastboot(args.serial, c)
    print("\nDone. Reboot with: fastboot reboot")


if __name__ == "__main__":
    main()
