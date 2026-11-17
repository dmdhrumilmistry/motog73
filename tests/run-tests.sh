#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Offline tests for the helper scripts, using small synthetic images
# (no device and no real firmware needed).
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="${TOOLS:-$ROOT/src/tools}"
export TOOLS
"$ROOT/scripts/fetch-tools.sh" --quiet
MKBOOTIMG=(python3 "$TOOLS/mkbootimg/mkbootimg.py")
UNPACK=(python3 "$TOOLS/mkbootimg/unpack_bootimg.py")

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cd "$T"

pass=0
ok()   { echo "PASS: $*"; pass=$((pass + 1)); }
fail() { echo "FAIL: $*" >&2; exit 1; }

mkcpio() { # dir -> lz4 cpio
    (cd "$1" && find . | cpio -o -H newc --quiet | lz4 -l -q -c)
}

mkdir -p plat/lib/modules rec1 rec2
echo "module" > plat/lib/modules/a.ko
echo "a.ko"  > plat/lib/modules/modules.load
echo "one"   > rec1/marker
echo "two"   > rec2/marker
mkcpio plat > plat.lz4
mkcpio rec1 > rec1.lz4
mkcpio rec2 > rec2.lz4
head -c 2048 /dev/urandom > dtb

COMMON=(--header_version 4 --pagesize 4096 --base 0 --kernel_offset 0x40000000
        --ramdisk_offset 0x66f00000 --tags_offset 0x47c80000 --dtb_offset 0x47c80000)

"${MKBOOTIMG[@]}" "${COMMON[@]}" --dtb dtb --vendor_cmdline "bootopt=64S3,32N2,64N2" \
    --ramdisk_type platform --ramdisk_name "" --vendor_ramdisk_fragment plat.lz4 \
    --vendor_boot stock_vendor_boot.img

# 1. Add a recovery fragment to an image that has none.
"$ROOT/scripts/repack-vendor-boot.sh" -s stock_vendor_boot.img -r rec1.lz4 -o vb1.img >/dev/null
"${UNPACK[@]}" --boot_img vb1.img --out u1 > info1.txt
grep -q "name: recovery" info1.txt || fail "recovery fragment not added"
cmp -s u1/dtb dtb || fail "dtb changed"
cmp -s u1/vendor_ramdisk00 plat.lz4 || fail "platform ramdisk changed"
grep -q "bootopt=64S3,32N2,64N2" info1.txt || fail "vendor cmdline lost"
grep -q "kernel load address: 0x40000000" info1.txt || fail "load address changed"
ok "repack-vendor-boot adds recovery fragment and preserves stock data"

# 2. Replace an existing recovery fragment, taking it from a TWRP-style vendor_boot.
"${MKBOOTIMG[@]}" "${COMMON[@]}" --dtb dtb \
    --ramdisk_type platform --ramdisk_name "" --vendor_ramdisk_fragment plat.lz4 \
    --ramdisk_type recovery --ramdisk_name recovery --vendor_ramdisk_fragment rec2.lz4 \
    --vendor_boot twrp_vendor_boot.img
"$ROOT/scripts/repack-vendor-boot.sh" -s vb1.img -r twrp_vendor_boot.img -o vb2.img >/dev/null
"${UNPACK[@]}" --boot_img vb2.img --out u2 > info2.txt
[[ "$(grep -c 'type: 0x2' info2.txt)" == 1 ]] || fail "expected exactly one recovery fragment"
[[ "$(lz4 -dc u2/vendor_ramdisk01 | cpio -i --to-stdout marker --quiet 2>/dev/null)" == "two" ]] \
    || fail "recovery fragment not replaced"
ok "repack-vendor-boot replaces recovery fragment from a vendor_boot image"

# 3. Reject non-vendor_boot input.
if "$ROOT/scripts/repack-vendor-boot.sh" -s rec1.lz4 -r rec1.lz4 -o bad.img 2>/dev/null; then
    fail "accepted a non vendor_boot image"
fi
ok "repack-vendor-boot rejects invalid input"

# 4. Boot image kernel swap.
head -c 4000 /dev/urandom > k1
head -c 6000 /dev/urandom > k2
"${MKBOOTIMG[@]}" --header_version 4 --kernel k1 --ramdisk rec1.lz4 \
    --os_version 14.0.0 --os_patch_level 2025-09 --output stock_boot.img
"$ROOT/scripts/repack-boot.sh" -s stock_boot.img -k k2 -o boot2.img >/dev/null
"${UNPACK[@]}" --boot_img boot2.img --out ub > infob.txt
cmp -s ub/kernel k2 || fail "kernel not replaced"
cmp -s ub/ramdisk rec1.lz4 || fail "ramdisk changed"
grep -q "os patch level: 2025-09" infob.txt || fail "patch level lost"
ok "repack-boot swaps kernel and keeps header fields"

# 5. flashfile.xml parsing, MD5 checks and --keep-data.
mkdir fw
echo a > fw/boot.img
cat > fw/flashfile.xml <<XML
<?xml version="1.0"?>
<flashing>
  <header><phone_model model="devonf_g"/></header>
  <steps interface="AP">
    <step operation="oem" var="fb_mode_set"/>
    <step operation="flash" partition="boot_a" filename="boot.img" MD5="$(md5sum fw/boot.img | cut -d' ' -f1)"/>
    <step operation="erase" partition="userdata"/>
    <step operation="oem" var="fb_mode_clear"/>
  </steps>
</flashing>
XML
out="$(python3 "$ROOT/scripts/moto-flashfile.py" fw)"
grep -q "fastboot flash boot_a" <<<"$out" || fail "flash step missing"
grep -q "fastboot erase userdata" <<<"$out" || fail "erase step missing"
out="$(python3 "$ROOT/scripts/moto-flashfile.py" fw --keep-data)"
grep -q "erase userdata" <<<"$out" && fail "--keep-data still erases userdata"
echo b > fw/boot.img
if python3 "$ROOT/scripts/moto-flashfile.py" fw >/dev/null 2>&1; then
    fail "MD5 mismatch not detected"
fi
ok "moto-flashfile parses steps, honours --keep-data and checks MD5"

# 6. postmarketOS package validation (checks against $PMAPORTS schema if set).
python3 "$ROOT/tests/check-pmos-packages.py" >pmos-check.txt 2>&1 \
    || { cat pmos-check.txt >&2; fail "postmarketOS package checks failed"; }
ok "postmarketOS packages pass offline validation"

# 7. pmaports-import.sh dry run copies both packages and prints pmbootstrap commands.
mkdir -p fake-pmaports/device
: > fake-pmaports/deviceinfo_schema.toml
"$ROOT/linux/postmarketos/pmaports-import.sh" --dry-run --pmaports fake-pmaports >import.txt 2>&1 \
    || { cat import.txt >&2; fail "pmaports-import.sh --dry-run failed"; }
[[ -f fake-pmaports/device/downstream/device-motorola-devonf/APKBUILD ]] \
    || fail "device package not copied"
[[ -f fake-pmaports/device/downstream/linux-motorola-devonf/APKBUILD ]] \
    || fail "kernel package not copied"
grep -q "pmbootstrap checksum" import.txt || fail "pmbootstrap checksum not printed"
ok "pmaports-import.sh --dry-run copies packages and prints pmbootstrap commands"

echo "All $pass tests passed."
