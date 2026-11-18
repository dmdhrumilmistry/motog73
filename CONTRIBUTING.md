# Contributing

Contributions are welcome: hardware test reports, fixes to the trees, scripts
and docs.

## Ground rules

1. **No proprietary blobs.** Don't commit firmware images, vendor libraries,
   `.ko` files from stock, DTBs extracted from stock, or anything produced by
   `scripts/extract-stock-images.sh`.
2. **No secrets or personal data.** No signing keys, no `.env`, no IMEI or
   serial numbers, no `nvram`/`persist` dumps, no logs that contain them. When
   sharing logs, remove `ro.serialno`, IMEI, MAC addresses, account names and
   Wi-Fi names first.
3. **Keep it reproducible.** Pin upstream revisions (tags or branches) in
   manifests and APKBUILDs.
4. **Shell scripts** must pass `shellcheck`. XML must be well-formed. CI checks both.
5. **GitHub Actions workflows** in `.github/workflows/` must pass `actionlint`
   (CI runs it; locally: `pip install actionlint-py` then `actionlint`). See
   [docs/ci.md](docs/ci.md) for what the workflows do.

## Workflow

1. Fork, create a topic branch from `main`.
2. Make focused commits with clear messages.
3. Open a pull request against `main` and fill in the template.

## Testing on hardware

Use the "Device report" issue template. Include your model (`XT2237-x`), the
stock build you started from, what you flashed, and what works or fails.
