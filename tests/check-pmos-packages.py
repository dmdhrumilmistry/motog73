#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Offline validation of the postmarketOS packages (no pmbootstrap needed).

Mirrors the relevant rules of pmaports' .ci/testcases (test_deviceinfo.py,
test_device.py, test_kernel.py). If the PMAPORTS environment variable points
at a pmaports checkout, deviceinfo keys are also checked against its
deviceinfo_schema.toml.
"""
import hashlib
import os
import re
import sys
import tomllib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PMOS = os.path.join(ROOT, "linux", "postmarketos")
DEV_DIR = os.path.join(PMOS, "device-motorola-devonf")
KRN_DIR = os.path.join(PMOS, "linux-motorola-devonf")

failures = 0


def report(ok, msg):
    global failures
    if not ok:
        failures += 1
    print(("PASS" if ok else "FAIL") + ": " + msg)


def skip(msg):
    print("SKIP: " + msg)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def parse_deviceinfo(path):
    """Return (list of invalid lines, dict of key -> value)."""
    bad, values = [], {}
    pattern = re.compile(r'^deviceinfo_[a-zA-Z0-9_]*=".*"(\s*# .*)?$')
    for line in read(path).split("\n"):
        if not line.strip() or line.startswith("#"):
            continue
        if not pattern.match(line) or line.endswith('\\"'):
            bad.append(line)
            continue
        key, _, rest = line.partition("=")
        m = re.match(r'"(.*?)"(\s*# .*)?$', rest)
        values[key] = m.group(1) if m else rest.strip('"')
    return bad, values


def parse_apkbuild(path):
    """Simple shell-ish parser for the variables we need."""
    text = read(path)
    variables = {}
    for m in re.finditer(r'^([A-Za-z_][A-Za-z0-9_]*)=(?:"([^"]*)"|\'([^\']*)\'|(\S*))',
                         text, re.M):
        name = m.group(1)
        val = next(g for g in m.group(2, 3, 4) if g is not None)
        variables[name] = val
    return variables


def expand(value, variables):
    def sub(m):
        name = m.group(1) or m.group(2)
        return variables.get(name, m.group(0))
    prev = None
    while prev != value:
        prev = value
        value = re.sub(r'\$\{(\w+)\}|\$(\w+)', sub, value)
    return value


def apk_vars(path):
    v = parse_apkbuild(path)
    v.setdefault("arch_", v.get("arch", ""))
    v["CARCH"] = v["arch"] = v.get("arch", "")
    v["pkgname"] = v.get("pkgname", "")
    for k in list(v):  # resolve references between variables
        v[k] = expand(v[k], v)
    return v


def word_list(s):
    return s.split()


def check_sources(pkgdir, label):
    apkbuild = os.path.join(pkgdir, "APKBUILD")
    v = apk_vars(apkbuild)
    sources = [expand(s, v) for s in word_list(v.get("source", ""))]
    sums = {}
    for line in v.get("sha512sums", "").split("\n"):
        parts = line.split()
        if len(parts) == 2:
            sums[parts[1]] = parts[0]
    report(bool(sources), f"{label}: APKBUILD source= parsed ({len(sources)} entries)")

    local = []
    for src in sources:
        if "::" in src:
            fname, url = src.split("::", 1)
        else:
            fname, url = os.path.basename(src), src
        is_url = re.match(r'^[a-z]+://', url) is not None
        if is_url:
            report(fname in sums, f"{label}: remote source {fname} has a sha512sums entry")
            continue
        local.append(fname)
        path = os.path.join(pkgdir, fname)
        if not os.path.isfile(path):
            report(False, f"{label}: local source {fname} exists")
            continue
        report(True, f"{label}: local source {fname} exists")
        expected = sums.get(fname)
        if expected is None:
            report(False, f"{label}: {fname} has a sha512sums entry")
        elif expected == "RUN_PMBOOTSTRAP_CHECKSUM":
            continue
        else:
            with open(path, "rb") as f:
                actual = hashlib.sha512(f.read()).hexdigest()
            report(actual == expected, f"{label}: sha512 of {fname} matches")
    for name in sums:
        if name not in [s.split("::")[0] if "::" in s else os.path.basename(s)
                        for s in sources]:
            report(False, f"{label}: sha512sums entry {name} has no source")

    for fname in sorted(os.listdir(pkgdir)):
        if fname == "APKBUILD":
            continue
        report(fname in local, f"{label}: file {fname} is listed in source=")
    return v


def load_schema(pmaports):
    """Return (known, obsolete) deviceinfo variable names.

    Schema layout: [variable.<category>.<name>] tables; obsolete ones carry
    fate = "obsolete". Names may be used with a device variant suffix when
    allow_device_variant_suffix = true.
    """
    with open(os.path.join(pmaports, "deviceinfo_schema.toml"), "rb") as f:
        schema = tomllib.load(f)
    known, obsolete, suffixable = set(), set(), set()
    for cat in schema.get("variable", {}).values():
        for name, spec in cat.items():
            known.add(name)
            if spec.get("fate") == "obsolete":
                obsolete.add(name)
            if spec.get("allow_device_variant_suffix"):
                suffixable.add(name)
    return known, obsolete, suffixable


def main():
    # deviceinfo
    di = os.path.join(DEV_DIR, "deviceinfo")
    bad, info = parse_deviceinfo(di)
    for line in bad:
        print("  invalid line: " + line)
    report(not bad, "deviceinfo: every line matches the deviceinfo regex")
    name = info.get("deviceinfo_name", "")
    manu = info.get("deviceinfo_manufacturer", "")
    report(bool(manu) and name.startswith(manu),
           "deviceinfo: deviceinfo_name starts with deviceinfo_manufacturer")

    pm = os.environ.get("PMAPORTS", "")
    if pm and os.path.isfile(os.path.join(pm, "deviceinfo_schema.toml")):
        known, obsolete, suffixable = load_schema(pm)
        unknown, obs = [], []
        for key in info:
            var = key[len("deviceinfo_"):]
            base = var
            if var not in known:
                base = next((b for b in suffixable if var.startswith(b + "_")), None)
            if base is None:
                unknown.append(key)
            elif base in obsolete:
                obs.append(key)
        for k in unknown:
            print("  unknown to schema: " + k)
        for k in obs:
            print("  obsolete in schema: " + k)
        report(not unknown, "deviceinfo: all keys are known to deviceinfo_schema.toml")
        report(not obs, "deviceinfo: no key is marked obsolete in deviceinfo_schema.toml")
    else:
        skip("deviceinfo schema check (set PMAPORTS to a pmaports checkout)")

    # device package
    dv = check_sources(DEV_DIR, "device-motorola-devonf")
    report("postmarketos-base" in dv.get("depends", "").split(),
           "device APKBUILD: depends has postmarketos-base")
    report("!archcheck" in dv.get("options", "").split(),
           "device APKBUILD: options has !archcheck")
    if info.get("deviceinfo_generate_bootimg") == "true":
        # boot-deploy refuses to create boot.img without android-tools
        report("android-tools" in dv.get("depends", "").split(),
               "device APKBUILD: depends has android-tools (generate_bootimg)")
    report(not any(m.startswith("maintainer") and '""' in m
                   for m in read(os.path.join(DEV_DIR, "APKBUILD")).splitlines()),
           "device APKBUILD: maintainer is set (abuild requires it)")
    report(dv.get("arch") == info.get("deviceinfo_arch"),
           f"device APKBUILD: arch ({dv.get('arch')}) equals deviceinfo_arch "
           f"({info.get('deviceinfo_arch')})")

    # kernel package
    kv = check_sources(KRN_DIR, "linux-motorola-devonf")
    report("pmb:cross-native" in kv.get("options", "").split(),
           "kernel APKBUILD: options has pmb:cross-native")

    if failures:
        print(f"{failures} check(s) failed", file=sys.stderr)
        return 1
    print("All package checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
