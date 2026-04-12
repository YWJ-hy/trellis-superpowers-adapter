#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_JSON="$SCRIPT_DIR/adapter.json"
HELPER="$SCRIPT_DIR/lib/trellis-target.sh"
TARGET_ARG="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"
SNAPSHOT_NAME="${2:-}"
DRY_RUN="${ADAPTER_DRY_RUN:-0}"
FORCE="${ADAPTER_FORCE:-0}"
BACKUP="${ADAPTER_BACKUP:-1}"
TIMESTAMP="${ADAPTER_TIMESTAMP:-$(python3 - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-%f'))
PY
)}"

create_snapshot_metadata() {
  local snapshot_dir="$1"
  local metadata_name="$2"
  local adapter_name="$3"
  local adapter_version="$4"
  local created_at="$5"
  local trellis_version="$6"
  local created_by="$7"
  local operation="$8"
  shift 8

  python3 - "$snapshot_dir" "$metadata_name" "$adapter_name" "$adapter_version" "$created_at" "$trellis_version" "$created_by" "$operation" "$@" <<'PY'
import json
import os
import sys

snapshot_dir, metadata_name, adapter_name, adapter_version, created_at, trellis_version, created_by, operation, *files = sys.argv[1:]
path = os.path.join(snapshot_dir, metadata_name)
with open(path, 'w') as f:
    json.dump({
        'adapterName': adapter_name,
        'adapterVersion': adapter_version,
        'createdAt': created_at,
        'trellisVersion': trellis_version,
        'createdBy': created_by,
        'operation': operation,
        'files': files,
    }, f, indent=2)
    f.write('\n')
PY
}

if [[ ! -f "$HELPER" ]]; then
  printf 'Missing Trellis target helper: %s\n' "$HELPER" >&2
  exit 1
fi

# shellcheck source=lib/trellis-target.sh
source "$HELPER"

load_adapter_core_metadata
load_adapter_installed_paths
load_adapter_patched_paths
require_real_trellis_project "$TARGET_DIR"

if [[ -z "$SNAPSHOT_NAME" ]]; then
  printf 'Usage: %s <trellis-project> <snapshot-name>\n' "$0" >&2
  exit 1
fi

SNAPSHOT_DIR="$TARGET_DIR/$BACKUP_ROOT_REL/$SNAPSHOT_NAME"
RESTORE_BACKUP_DIR="$TARGET_DIR/$BACKUP_ROOT_REL/restore-$TIMESTAMP"

if [[ ! -d "$SNAPSHOT_DIR" ]]; then
  printf 'Backup snapshot does not exist: %s\n' "$SNAPSHOT_DIR" >&2
  exit 1
fi

SNAPSHOT_PATHS=$(python3 - "$SNAPSHOT_DIR" "$ADAPTER_JSON" "$SNAPSHOT_METADATA_FILE" <<'PY'
import json
import os
import sys

snapshot_dir = sys.argv[1]
adapter_json = json.load(open(sys.argv[2]))
metadata_name = sys.argv[3]
allowed = set(adapter_json["installedPaths"]) | set(adapter_json.get("patchedPaths", []))
found = []
metadata = None

for root, _, files in os.walk(snapshot_dir):
    for name in files:
        rel = os.path.relpath(os.path.join(root, name), snapshot_dir)
        if rel == metadata_name:
            metadata = json.load(open(os.path.join(root, name)))
            continue
        if rel not in allowed:
            raise SystemExit(f'Unexpected file in snapshot: {rel}')
        found.append(rel)

if not found:
    raise SystemExit(f'Snapshot contains no restorable adapter files: {snapshot_dir}')

if metadata is not None:
    metadata_files = sorted(metadata.get("files", []))
    actual_files = sorted(found)
    if metadata_files and metadata_files != actual_files:
        raise SystemExit(f'Snapshot metadata file list does not match snapshot contents: {snapshot_dir}')

for rel in sorted(found):
    print(rel)
PY
)

declare -a CONFLICT_FILES=()
while IFS= read -r relative_path; do
  [[ -z "$relative_path" ]] && continue
  SNAPSHOT_FILE="$SNAPSHOT_DIR/$relative_path"
  TARGET_FILE="$TARGET_DIR/$relative_path"
  if [[ -f "$TARGET_FILE" ]] && ! cmp -s "$SNAPSHOT_FILE" "$TARGET_FILE"; then
    CONFLICT_FILES+=("$relative_path")
  fi
done <<< "$SNAPSHOT_PATHS"

if [[ "$DRY_RUN" == "1" ]]; then
  printf '[dry-run] Would restore adapter snapshot %s into %s\n' "$SNAPSHOT_NAME" "$TARGET_DIR"
  while IFS= read -r relative_path; do
    [[ -z "$relative_path" ]] && continue
    printf '[dry-run] Would restore %s -> %s\n' "$SNAPSHOT_DIR/$relative_path" "$TARGET_DIR/$relative_path"
  done <<< "$SNAPSHOT_PATHS"
  if [[ ${#CONFLICT_FILES[@]} -gt 0 ]]; then
    printf '[dry-run] Detected conflicting current files:\n'
    for relative_path in "${CONFLICT_FILES[@]}"; do
      printf '[dry-run]   %s\n' "$TARGET_DIR/$relative_path"
    done
    if [[ "$FORCE" == "1" ]]; then
      if [[ "$BACKUP" == "1" ]]; then
        printf '[dry-run] Would back up current files to %s before restore\n' "$RESTORE_BACKUP_DIR"
        printf '[dry-run] Would write snapshot metadata to %s/%s\n' "$RESTORE_BACKUP_DIR" "$SNAPSHOT_METADATA_FILE"
      else
        printf '[dry-run] Would overwrite current files without backup before restore\n'
      fi
    else
      printf '[dry-run] Restore would stop unless ADAPTER_FORCE=1 is provided\n'
    fi
  fi
  exit 0
fi

if [[ ${#CONFLICT_FILES[@]} -gt 0 && "$FORCE" != "1" ]]; then
  printf 'Detected conflicting current files in %s\n' "$TARGET_DIR" >&2
  for relative_path in "${CONFLICT_FILES[@]}"; do
    printf '  %s\n' "$TARGET_DIR/$relative_path" >&2
  done
  printf 'Refusing to overwrite current files. Re-run with ADAPTER_FORCE=1 to allow restore.\n' >&2
  printf 'Backups are enabled by default when forcing. Disable with ADAPTER_BACKUP=0 if you really want no backup.\n' >&2
  exit 1
fi

if [[ ${#CONFLICT_FILES[@]} -gt 0 && "$FORCE" == "1" && "$BACKUP" == "1" ]]; then
  for relative_path in "${CONFLICT_FILES[@]}"; do
    mkdir -p "$RESTORE_BACKUP_DIR/$(dirname "$relative_path")"
    cp "$TARGET_DIR/$relative_path" "$RESTORE_BACKUP_DIR/$relative_path"
  done
  create_snapshot_metadata "$RESTORE_BACKUP_DIR" "$SNAPSHOT_METADATA_FILE" "$ADAPTER_NAME" "$ADAPTER_VERSION" "$TIMESTAMP" "$TRELLIS_VERSION" "restore.sh" "force-restore-backup" "${CONFLICT_FILES[@]}"
fi

while IFS= read -r relative_path; do
  [[ -z "$relative_path" ]] && continue
  mkdir -p "$TARGET_DIR/$(dirname "$relative_path")"
  cp "$SNAPSHOT_DIR/$relative_path" "$TARGET_DIR/$relative_path"
done <<< "$SNAPSHOT_PATHS"

printf 'Restored adapter snapshot %s into %s\n' "$SNAPSHOT_NAME" "$TARGET_DIR"
if [[ ${#CONFLICT_FILES[@]} -gt 0 ]]; then
  printf 'Restored over %s conflicting file(s)\n' "${#CONFLICT_FILES[@]}"
  if [[ "$FORCE" == "1" && "$BACKUP" == "1" ]]; then
    printf 'Backed up replaced current files to %s\n' "$RESTORE_BACKUP_DIR"
  fi
fi
printf 'Next step: run %s/verify.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR"
