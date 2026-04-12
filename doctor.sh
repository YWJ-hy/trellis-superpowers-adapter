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
ERROR_COUNT=0
WARN_COUNT=0
declare -a MISSING_FILES=()
while IFS= read -r relative_path; do
  [[ -z "$relative_path" ]] && continue
  if [[ -f "$TARGET_DIR/$relative_path" ]]; then
    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
  else
    MISSING_COUNT=$((MISSING_COUNT + 1))
    MISSING_FILES+=("$relative_path")
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
text = path.read_text()
start_count = text.count(marker_start)
end_count = text.count(marker_end)
if start_count == 1 and end_count == 1:
    print('patched')
elif start_count == 0 and end_count == 0:
    print('unpatched')
else:
    print('drifted')
PY
)

VERIFY_OUTPUT=""
VERIFY_STATUS="passed"
if ! VERIFY_OUTPUT=$("$SCRIPT_DIR/verify.sh" "$TARGET_DIR" 2>&1); then
  VERIFY_STATUS="failed"
fi

SNAPSHOT_STATS=$(python3 - "$BACKUP_ROOT" "$SNAPSHOT_METADATA_FILE" <<'PY'
import os
import sys

root = sys.argv[1]
metadata_name = sys.argv[2]
if not os.path.isdir(root):
    print('0|0|0')
    raise SystemExit(0)

total = 0
with_metadata = 0
legacy = 0
for name in os.listdir(root):
    path = os.path.join(root, name)
    if not os.path.isdir(path):
        continue
    total += 1
    metadata_path = os.path.join(path, metadata_name)
    if os.path.isfile(metadata_path):
        with_metadata += 1
    else:
        legacy += 1

print(f'{total}|{with_metadata}|{legacy}')
PY
)

IFS='|' read -r SNAPSHOT_TOTAL SNAPSHOT_WITH_METADATA SNAPSHOT_LEGACY <<< "$SNAPSHOT_STATS"

printf 'Adapter doctor\n'
printf '  adapter: %s@%s\n' "$ADAPTER_NAME" "$ADAPTER_VERSION"
printf '  target: %s\n' "$TARGET_DIR"
printf '  trellisVersion: %s\n' "$TRELLIS_VERSION"

if [[ "$MISSING_COUNT" -eq 0 ]]; then
  printf '  installState: OK (%s/%s overlay files present)\n' "$INSTALLED_COUNT" "$INSTALLED_COUNT"
else
  ERROR_COUNT=$((ERROR_COUNT + 1))
  TOTAL_COUNT=$((INSTALLED_COUNT + MISSING_COUNT))
  printf '  installState: FAIL (%s/%s overlay files present)\n' "$INSTALLED_COUNT" "$TOTAL_COUNT"
fi

if [[ "$PATCH_STATUS" == "patched" ]]; then
  printf '  startInterop: OK\n'
elif [[ "$PATCH_STATUS" == "unpatched" ]]; then
  ERROR_COUNT=$((ERROR_COUNT + 1))
  printf '  startInterop: FAIL (interop block missing)\n'
else
  ERROR_COUNT=$((ERROR_COUNT + 1))
  printf '  startInterop: FAIL (%s)\n' "$PATCH_STATUS"
fi

if [[ "$VERIFY_STATUS" == "passed" ]]; then
  printf '  verifyState: OK\n'
else
  ERROR_COUNT=$((ERROR_COUNT + 1))
  printf '  verifyState: FAIL\n'
fi

if [[ "$TRELLIS_TEMPLATE_HASHES_PRESENT" == "1" ]]; then
  printf '  templateHashes: OK\n'
else
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '  templateHashes: WARN (missing %s)\n' "$TRELLIS_TEMPLATE_HASHES_FILE"
fi

if [[ "$SNAPSHOT_TOTAL" -eq 0 ]]; then
  printf '  backups: none\n'
elif [[ "$SNAPSHOT_LEGACY" -eq 0 ]]; then
  printf '  backups: OK (%s snapshot(s), all with metadata)\n' "$SNAPSHOT_TOTAL"
else
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '  backups: WARN (%s snapshot(s), %s legacy without metadata)\n' "$SNAPSHOT_TOTAL" "$SNAPSHOT_LEGACY"
fi

printf '\nRecommendations\n'
if [[ "$MISSING_COUNT" -gt 0 ]]; then
  for relative_path in "${MISSING_FILES[@]}"; do
    printf '  - Missing overlay file: %s\n' "$relative_path"
  done
  printf '  - Run: %s/install.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR"
fi

if [[ "$PATCH_STATUS" != "patched" ]]; then
  printf '  - The start command interop block is not healthy. Run: %s/install.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR"
  printf '  - Inspect current backups with: %s/list-backups.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR"
fi

if [[ "$VERIFY_STATUS" == "failed" ]]; then
  printf '  - verify.sh is failing. Run: %s/verify.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR"
  printf '  - If adapter files drifted, inspect backups with: %s/list-backups.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR"
  printf '  - Restore a snapshot with: %s/restore.sh "%s" <snapshot-name>\n' "$SCRIPT_DIR" "$TARGET_DIR"
fi

if [[ "$TRELLIS_TEMPLATE_HASHES_PRESENT" != "1" ]]; then
  printf '  - Re-run `trellis init` or Trellis update tooling if this project should have template hash tracking.\n'
fi

if [[ "$SNAPSHOT_LEGACY" -gt 0 ]]; then
  printf '  - %s legacy snapshot(s) predate snapshot metadata. Keep them if useful or prune them with: %s/prune-backups.sh "%s" delete <snapshot-name>\n' "$SNAPSHOT_LEGACY" "$SCRIPT_DIR" "$TARGET_DIR"
fi

if [[ "$SNAPSHOT_TOTAL" -gt 5 ]]; then
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '  - Backup count is growing. Consider pruning old snapshots with: %s/prune-backups.sh "%s" keep-latest 5\n' "$SCRIPT_DIR" "$TARGET_DIR"
fi

if [[ "$ERROR_COUNT" -eq 0 && "$WARN_COUNT" -eq 0 ]]; then
  printf '  - No action needed. Adapter looks healthy.\n'
fi

if [[ "$VERIFY_STATUS" == "failed" ]]; then
  printf '\nverify.sh output\n%s\n' "$VERIFY_OUTPUT"
fi

if [[ "$ERROR_COUNT" -gt 0 ]]; then
  exit 1
fi
