#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ARG="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"

MANIFEST_JSON=$("$SCRIPT_DIR/export-manifest.sh" "$TARGET_DIR")

BOOTSTRAP_DECISION=$(python3 - <<'PY' "$MANIFEST_JSON" | tr -d '\r'
import json
import sys

manifest = json.loads(sys.argv[1])
missing = manifest["installState"]["missingFileCount"]
installed = manifest["installState"]["installedFileCount"]
verify_status = manifest["verify"]["status"]
required = installed + missing

if installed == 0:
    print('install')
elif missing == 0 and verify_status == 'passed':
    print('healthy')
else:
    print('manual')
PY
)

case "$BOOTSTRAP_DECISION" in
  install)
    printf 'Bootstrap: adapter not detected, installing into %s\n' "$TARGET_DIR"
    "$SCRIPT_DIR/install.sh" "$TARGET_DIR"
    "$SCRIPT_DIR/verify.sh" "$TARGET_DIR"
    ;;
  healthy)
    printf 'Bootstrap: adapter already installed and healthy in %s\n' "$TARGET_DIR"
    "$SCRIPT_DIR/verify.sh" "$TARGET_DIR"
    ;;
  manual)
    printf 'Bootstrap: adapter is partially installed or unhealthy in %s\n' "$TARGET_DIR" >&2
    printf 'Refusing to make repair decisions automatically.\n' >&2
    printf 'Next steps:\n' >&2
    printf '  %s/doctor.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR" >&2
    printf '  %s/install.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR" >&2
    printf '  %s/list-backups.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR" >&2
    exit 1
    ;;
  *)
    printf 'Unexpected bootstrap decision: %s\n' "$BOOTSTRAP_DECISION" >&2
    exit 1
    ;;
esac
