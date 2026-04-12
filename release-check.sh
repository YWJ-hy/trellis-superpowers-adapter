#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ARG="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"

printf 'Release check: self-test\n'
"$SCRIPT_DIR/self-test.sh" "$TARGET_DIR"

printf '\nRelease check: real-project target regression\n'
"$SCRIPT_DIR/tests/real-project-target-regression.sh"

printf '\nRelease check: export-manifest\n'
MANIFEST_OUTPUT=$("$SCRIPT_DIR/export-manifest.sh" "$TARGET_DIR")
python3 - <<'PY' "$MANIFEST_OUTPUT"
import json
import sys
manifest = json.loads(sys.argv[1])
assert manifest['adapter']['name'] == 'trellis-superpowers-adapter'
assert 'version' in manifest['adapter']
assert 'trellisVersion' in manifest['target']
assert 'versionSource' in manifest['target']
assert 'templateHashesPresent' in manifest['target']
assert 'status' in manifest['verify']
assert 'snapshots' in manifest['backups']
print('manifest structure OK')
PY

printf '\nRelease check completed successfully\n'
