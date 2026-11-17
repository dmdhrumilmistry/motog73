#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
# Generate YOUR OWN private signing keys for LineageOS builds
# (follows https://wiki.lineageos.org/signing_builds).
#
# Keys are written to <lineage-source>/vendor/lineage-priv/keys, which
# LineageOS picks up automatically. They never belong in this repository
# or any public place: whoever has them can sign updates for your phone.
#
# Usage:
#   rom/gen-keys.sh
#
# Environment:
#   LINEAGE_DIR   source checkout (default: src/lineage)
#   KEY_SUBJECT   certificate subject (default: a neutral, non-personal one)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINEAGE_DIR="${LINEAGE_DIR:-$ROOT/src/lineage}"
KEY_SUBJECT="${KEY_SUBJECT:-/C=US/ST=None/L=None/O=G73Open/OU=G73Open/CN=G73Open}"
KEYS_DIR="$LINEAGE_DIR/vendor/lineage-priv/keys"
MAKE_KEY="$LINEAGE_DIR/development/tools/make_key"

[[ -x "$MAKE_KEY" ]] || { echo "error: $MAKE_KEY not found (sync the source first)" >&2; exit 1; }
if [[ -f "$KEYS_DIR/releasekey.pk8" ]]; then
    echo "Keys already exist in $KEYS_DIR, refusing to overwrite."
    exit 0
fi

mkdir -p "$KEYS_DIR"
chmod 700 "$KEYS_DIR"
for cert in bluetooth cyngn-app media networkstack nfc platform releasekey \
            sdk_sandbox shared testcert testkey verity; do
    echo ">> $cert"
    # Empty password: the build system cannot prompt for one.
    printf '\n\n' | "$MAKE_KEY" "$KEYS_DIR/$cert" "$KEY_SUBJECT" >/dev/null 2>&1 || true
    [[ -f "$KEYS_DIR/$cert.pk8" ]] || { echo "error: failed to create $cert" >&2; exit 1; }
done

cat > "$KEYS_DIR/keys.mk" <<'MK'
PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/lineage-priv/keys/releasekey
MK
cat > "$KEYS_DIR/BUILD.bazel" <<'BZL'
filegroup(
    name = "android_certificate_directory",
    srcs = glob([
        "*.pk8",
        "*.pem",
    ]),
    visibility = ["//visibility:public"],
)
BZL

echo
echo ">> Keys created in $KEYS_DIR"
echo "   Back them up somewhere private. Losing them means future builds"
echo "   cannot be installed as updates over your current one."
