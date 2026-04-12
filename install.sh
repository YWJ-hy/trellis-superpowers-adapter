#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="$SCRIPT_DIR/overlay"
ADAPTER_JSON="$SCRIPT_DIR/adapter.json"
HELPER="$SCRIPT_DIR/lib/trellis-target.sh"
TARGET_ARG="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"
DRY_RUN="${ADAPTER_DRY_RUN:-0}"
FORCE="${ADAPTER_FORCE:-0}"
BACKUP="${ADAPTER_BACKUP:-1}"
TIMESTAMP="${ADAPTER_TIMESTAMP:-$(python3 - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-%f'))
PY
)}"

if [[ ! -f "$HELPER" ]]; then
  printf 'Missing Trellis target helper: %s\n' "$HELPER" >&2
  exit 1
fi

# shellcheck source=lib/trellis-target.sh
source "$HELPER"

REQUIRED_OVERLAY_FILES=(
  ".claude/commands/trellis-sp/brainstorm.md"
  ".claude/commands/trellis-sp/specify.md"
  ".claude/commands/trellis-sp/clarify.md"
  ".claude/commands/trellis-sp/plan.md"
  ".claude/commands/trellis-sp/execute.md"
  ".claude/skills/trellis-sp-local/SKILL.md"
)

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

start_interop_target() {
  printf '%s/%s\n' "$TARGET_DIR" "$START_INTEROP_PATH"
}

has_start_interop_block() {
  local target_file="$1"
  [[ -f "$target_file" ]] && grep -Fq -- "$START_INTEROP_MARKER_START" "$target_file"
}

start_interop_block_matches() {
  local target_file="$1"
  local expected_block="$2"
  python3 - "$target_file" "$START_INTEROP_MARKER_START" "$START_INTEROP_MARKER_END" "$expected_block" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
marker_start = sys.argv[2]
marker_end = sys.argv[3]
expected = sys.argv[4]
text = path.read_text()
start = text.find(marker_start)
end = text.find(marker_end)
if start == -1 or end == -1:
    raise SystemExit(1)
end += len(marker_end)
block = text[start:end].strip() + "\n"
if block == expected:
    raise SystemExit(0)
raise SystemExit(1)
PY
}

append_start_interop_block() {
  local target_file="$1"
  local block="$2"
  python3 - "$target_file" "$block" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
block = sys.argv[2]
if not text.endswith('\n'):
    text += '\n'
if not text.endswith('\n\n'):
    text += '\n'
text += block
path.write_text(text)
PY
}

remove_start_interop_block() {
  local target_file="$1"
  python3 - "$target_file" "$START_INTEROP_MARKER_START" "$START_INTEROP_MARKER_END" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
marker_start = sys.argv[2]
marker_end = sys.argv[3]
text = path.read_text()
start = text.find(marker_start)
end = text.find(marker_end)
if start == -1 or end == -1:
    raise SystemExit(0)
end += len(marker_end)
if end < len(text) and text[end:end+1] == '\n':
    end += 1
while start > 0 and text[start-1:start] == '\n' and start - 1 > 0 and text[start-2:start-1] == '\n':
    start -= 1
new_text = text[:start].rstrip('\n')
if new_text:
    new_text += '\n'
path.write_text(new_text)
PY
}

load_adapter_core_metadata
load_adapter_patch_metadata
require_real_trellis_project "$TARGET_DIR"
assert_trellis_version_at_least "$TRELLIS_VERSION" "$MIN_VERSION"
BACKUP_DIR="$TARGET_DIR/$BACKUP_ROOT_REL/$TIMESTAMP"
START_FILE="$(start_interop_target)"
START_BLOCK="$(render_start_interop_block)"

for relative_path in "${REQUIRED_OVERLAY_FILES[@]}"; do
  if [[ ! -f "$OVERLAY_DIR/$relative_path" ]]; then
    printf 'Missing overlay file: %s\n' "$OVERLAY_DIR/$relative_path" >&2
    exit 1
  fi
done

if [[ ! -f "$START_FILE" ]]; then
  printf 'Missing Trellis start command for interop patch: %s\n' "$START_FILE" >&2
  exit 1
fi

declare -a CONFLICT_FILES=()
for relative_path in "${REQUIRED_OVERLAY_FILES[@]}"; do
  TARGET_FILE="$TARGET_DIR/$relative_path"
  SOURCE_FILE="$OVERLAY_DIR/$relative_path"
  if [[ -f "$TARGET_FILE" ]] && ! cmp -s "$SOURCE_FILE" "$TARGET_FILE"; then
    CONFLICT_FILES+=("$relative_path")
  fi
done

START_PATCH_STATE="missing"
if has_start_interop_block "$START_FILE"; then
  if start_interop_block_matches "$START_FILE" "$START_BLOCK"; then
    START_PATCH_STATE="present"
  else
    START_PATCH_STATE="drifted"
    CONFLICT_FILES+=("$START_INTEROP_PATH")
  fi
fi

if [[ "$DRY_RUN" == "1" ]]; then
  printf '[dry-run] Would install adapter into %s\n' "$TARGET_DIR"
  printf '[dry-run] Trellis version %s satisfies minimum %s\n' "$TRELLIS_VERSION" "$MIN_VERSION"
  for relative_path in "${REQUIRED_OVERLAY_FILES[@]}"; do
    printf '[dry-run] Would copy %s -> %s\n' "$OVERLAY_DIR/$relative_path" "$TARGET_DIR/$relative_path"
  done
  case "$START_PATCH_STATE" in
    missing)
      printf '[dry-run] Would append start interop block to %s\n' "$START_FILE"
      ;;
    present)
      printf '[dry-run] Start interop block already present in %s\n' "$START_FILE"
      ;;
    drifted)
      printf '[dry-run] Start interop block in %s has drifted and would require force to rewrite\n' "$START_FILE"
      ;;
  esac
  if [[ ${#CONFLICT_FILES[@]} -gt 0 ]]; then
    printf '[dry-run] Detected conflicting files:\n'
    for relative_path in "${CONFLICT_FILES[@]}"; do
      printf '[dry-run]   %s\n' "$TARGET_DIR/$relative_path"
    done
    if [[ "$FORCE" == "1" ]]; then
      if [[ "$BACKUP" == "1" ]]; then
        printf '[dry-run] Would back up conflicting files to %s\n' "$BACKUP_DIR"
        printf '[dry-run] Would write snapshot metadata to %s/%s\n' "$BACKUP_DIR" "$SNAPSHOT_METADATA_FILE"
      else
        printf '[dry-run] Would overwrite conflicting files without backup\n'
      fi
    else
      printf '[dry-run] Install would stop unless ADAPTER_FORCE=1 is provided\n'
    fi
  fi
  exit 0
fi

if [[ ${#CONFLICT_FILES[@]} -gt 0 && "$FORCE" != "1" ]]; then
  printf 'Detected conflicting files in %s\n' "$TARGET_DIR" >&2
  for relative_path in "${CONFLICT_FILES[@]}"; do
    printf '  %s\n' "$TARGET_DIR/$relative_path" >&2
  done
  printf 'Refusing to overwrite changed files. Re-run with ADAPTER_FORCE=1 to allow replacement.\n' >&2
  printf 'Backups are enabled by default when forcing. Disable with ADAPTER_BACKUP=0 if you really want no backup.\n' >&2
  exit 1
fi

mkdir -p \
  "$TARGET_DIR/.claude/commands/trellis-sp" \
  "$TARGET_DIR/.claude/skills/trellis-sp-local"

if [[ ${#CONFLICT_FILES[@]} -gt 0 && "$FORCE" == "1" && "$BACKUP" == "1" ]]; then
  for relative_path in "${CONFLICT_FILES[@]}"; do
    mkdir -p "$BACKUP_DIR/$(dirname "$relative_path")"
    cp "$TARGET_DIR/$relative_path" "$BACKUP_DIR/$relative_path"
  done
  create_snapshot_metadata "$BACKUP_DIR" "$SNAPSHOT_METADATA_FILE" "$ADAPTER_NAME" "$ADAPTER_VERSION" "$TIMESTAMP" "$TRELLIS_VERSION" "install.sh" "force-install-backup" "${CONFLICT_FILES[@]}"
fi

for relative_path in "${REQUIRED_OVERLAY_FILES[@]}"; do
  cp "$OVERLAY_DIR/$relative_path" "$TARGET_DIR/$relative_path"
done

case "$START_PATCH_STATE" in
  missing)
    append_start_interop_block "$START_FILE" "$START_BLOCK"
    ;;
  present)
    ;;
  drifted)
    remove_start_interop_block "$START_FILE"
    append_start_interop_block "$START_FILE" "$START_BLOCK"
    ;;
esac

printf 'Installed Trellis-Superpowers adapter into %s\n' "$TARGET_DIR"
printf 'Detected Trellis version: %s\n' "$TRELLIS_VERSION"
if [[ ${#CONFLICT_FILES[@]} -gt 0 ]]; then
  printf 'Overwrote %s conflicting file(s)\n' "${#CONFLICT_FILES[@]}"
  if [[ "$FORCE" == "1" && "$BACKUP" == "1" ]]; then
    printf 'Backed up previous versions to %s\n' "$BACKUP_DIR"
  fi
fi
printf 'Patched start command interop: %s\n' "$START_INTEROP_PATH"
printf 'Available commands:\n'
printf '  /trellis-sp:brainstorm\n'
printf '  /trellis-sp:specify\n'
printf '  /trellis-sp:clarify\n'
printf '  /trellis-sp:plan\n'
printf '  /trellis-sp:execute\n'
printf 'Next step: run %s/verify.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR"
