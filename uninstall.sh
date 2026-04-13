#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_JSON="$SCRIPT_DIR/adapter.json"
HELPER="$SCRIPT_DIR/lib/trellis-target.sh"
TARGET_ARG="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"
DRY_RUN="${ADAPTER_DRY_RUN:-0}"

if [[ ! -f "$HELPER" ]]; then
  printf 'Missing Trellis target helper: %s\n' "$HELPER" >&2
  exit 1
fi

# shellcheck source=lib/trellis-target.sh
source "$HELPER"

remove_start_interop_block() {
  local target_file="$1"
  python3 - "$target_file" "$START_INTEROP_MARKER_START" "$START_INTEROP_MARKER_END" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
marker_start = sys.argv[2]
marker_end = sys.argv[3]
if not path.exists():
    raise SystemExit(0)
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
remainder = text[end:].lstrip('\n')
if new_text and remainder:
    new_text += '\n\n' + remainder
elif remainder:
    new_text = remainder
elif new_text:
    new_text += '\n'
path.write_text(new_text)
PY
}

load_adapter_core_metadata
load_adapter_installed_paths
load_adapter_patch_metadata
require_real_trellis_project "$TARGET_DIR"
INSTALLED_FILES="$INSTALLED_PATHS"
START_FILE="$TARGET_DIR/$START_INTEROP_PATH"

if [[ "$DRY_RUN" == "1" ]]; then
  printf '[dry-run] Would remove adapter from %s\n' "$TARGET_DIR"
  while IFS= read -r relative_path; do
    [[ -z "$relative_path" ]] && continue
    printf '[dry-run] Would remove %s\n' "$TARGET_DIR/$relative_path"
  done <<< "$INSTALLED_FILES"
  printf '[dry-run] Would remove managed interop block from %s if present\n' "$START_FILE"
  printf '[dry-run] Would try to remove empty directories %s, %s, and %s\n' \
    "$TARGET_DIR/.claude/commands/trellis-sp" \
    "$TARGET_DIR/.claude/skills/trellis-sp-local" \
    "$TARGET_DIR/.claude/scripts"
  exit 0
fi

while IFS= read -r relative_path; do
  [[ -z "$relative_path" ]] && continue
  rm -f "$TARGET_DIR/$relative_path"
done <<< "$INSTALLED_FILES"

remove_start_interop_block "$START_FILE"

rmdir "$TARGET_DIR/.claude/commands/trellis-sp" 2>/dev/null || true
rmdir "$TARGET_DIR/.claude/skills/trellis-sp-local" 2>/dev/null || true
rmdir "$TARGET_DIR/.claude/scripts" 2>/dev/null || true

printf 'Removed Trellis-Superpowers adapter from %s\n' "$TARGET_DIR"
printf 'Removed start command interop block from %s (if present)\n' "$START_FILE"
printf 'To reinstall, run %s/install.sh "%s"\n' "$SCRIPT_DIR" "$TARGET_DIR"
