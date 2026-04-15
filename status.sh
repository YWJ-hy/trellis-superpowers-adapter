#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_JSON="$SCRIPT_DIR/adapter.json"
HELPER="$SCRIPT_DIR/lib/trellis-target.sh"
TARGET_ARG="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"

if [[ ! -f "$HELPER" ]]; then
  printf 'Missing Trellis target helper: %s\n' "$HELPER" >&2
  exit 1
fi

# shellcheck source=lib/trellis-target.sh
source "$HELPER"

load_adapter_core_metadata
load_adapter_installed_paths
load_adapter_patch_metadata
require_real_trellis_project "$TARGET_DIR"
BACKUP_ROOT="$TARGET_DIR/$BACKUP_ROOT_REL"

INSTALLED_COUNT=0
MISSING_COUNT=0
while IFS= read -r relative_path; do
  [[ -z "$relative_path" ]] && continue
  if [[ -f "$TARGET_DIR/$relative_path" ]]; then
    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
  else
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
done <<< "$INSTALLED_PATHS"

PATCH_STATUS=$(python3 - "$TARGET_DIR/$START_INTEROP_PATH" "$START_INTEROP_MARKER_START" "$START_INTEROP_MARKER_END" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
marker_start = sys.argv[2]
marker_end = sys.argv[3]
if not path.exists():
    print('missing-file')
    raise SystemExit(0)
text = path.read_text(encoding='utf-8')
start_count = text.count(marker_start)
end_count = text.count(marker_end)
if start_count == 1 and end_count == 1:
    print('patched')
elif start_count == 0 and end_count == 0:
    print('unpatched')
else:
    print(f'drifted ({start_count}/{end_count})')
PY
)

VERIFY_OUTPUT=""
VERIFY_STATUS="not-run"
if VERIFY_OUTPUT=$("$SCRIPT_DIR/verify.sh" "$TARGET_DIR" 2>&1); then
  VERIFY_STATUS="passed"
else
  VERIFY_STATUS="failed"
fi

SNAPSHOT_SUMMARY=$(python3 - "$BACKUP_ROOT" "$SNAPSHOT_METADATA_FILE" <<'PY'
import json
import os
import sys

root = sys.argv[1]
metadata_name = sys.argv[2]
if not os.path.isdir(root):
    print('none')
    raise SystemExit(0)

entries = []
for name in sorted(os.listdir(root), reverse=True):
    path = os.path.join(root, name)
    if not os.path.isdir(path):
        continue
    file_count = 0
    metadata = None
    for current_root, _, files in os.walk(path):
        for filename in files:
            rel = os.path.relpath(os.path.join(current_root, filename), path)
            if rel == metadata_name:
                metadata = json.load(open(os.path.join(current_root, filename), encoding='utf-8'))
                continue
            file_count += 1
    entries.append((name, file_count, metadata))

if not entries:
    print('none')
    raise SystemExit(0)

for name, file_count, metadata in entries[:5]:
    if metadata:
        print(f'{name}|{file_count}|{metadata.get("operation", "unknown")}|{metadata.get("createdAt", "unknown")}')
    else:
        print(f'{name}|{file_count}|legacy|unknown')
PY
)

printf 'Adapter status\n'
printf '  name: %s\n' "$ADAPTER_NAME"
printf '  version: %s\n' "$ADAPTER_VERSION"
printf '  target: %s\n' "$TARGET_DIR"
printf '  trellisVersion: %s\n' "$TRELLIS_VERSION"
if [[ "$TRELLIS_TEMPLATE_HASHES_PRESENT" == "1" ]]; then
  printf '  templateHashes: present\n'
else
  printf '  templateHashes: missing (%s)\n' "$TRELLIS_TEMPLATE_HASHES_FILE"
fi

if [[ "$MISSING_COUNT" -eq 0 ]]; then
  printf '  installed: yes (%s/%s overlay files present)\n' "$INSTALLED_COUNT" "$INSTALLED_COUNT"
else
  TOTAL_COUNT=$((INSTALLED_COUNT + MISSING_COUNT))
  printf '  installed: partial (%s/%s overlay files present)\n' "$INSTALLED_COUNT" "$TOTAL_COUNT"
fi

printf '  startInterop: %s\n' "$PATCH_STATUS"
printf '  verify: %s\n' "$VERIFY_STATUS"

if [[ "$VERIFY_STATUS" == "failed" ]]; then
  printf '\nVerify output:\n%s\n' "$VERIFY_OUTPUT"
fi

printf '\nRecent backup snapshots\n'
if [[ "$SNAPSHOT_SUMMARY" == "none" ]]; then
  printf '  none\n'
else
  while IFS='|' read -r name file_count operation created_at; do
    [[ -z "$name" ]] && continue
    printf '  - %s (%s file(s), %s, createdAt=%s)\n' "$name" "$file_count" "$operation" "$created_at"
  done <<< "$SNAPSHOT_SUMMARY"
fi
