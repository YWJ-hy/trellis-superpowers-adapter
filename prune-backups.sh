#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_JSON="$SCRIPT_DIR/adapter.json"
TARGET_ARG="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"
MODE="${2:-}"
VALUE="${3:-}"
DRY_RUN="${ADAPTER_DRY_RUN:-0}"

if [[ ! -f "$ADAPTER_JSON" ]]; then
  printf 'Missing adapter metadata: %s\n' "$ADAPTER_JSON" >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR/.trellis" ]]; then
  printf 'Target is not a Trellis project: %s\n' "$TARGET_DIR" >&2
  exit 1
fi

BACKUP_ROOT_REL=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["conflictPolicy"]["backupRoot"])' "$ADAPTER_JSON")
BACKUP_ROOT="$TARGET_DIR/$BACKUP_ROOT_REL"

if [[ ! -d "$BACKUP_ROOT" ]]; then
  printf 'No backup snapshots found under %s\n' "$BACKUP_ROOT" >&2
  exit 1
fi

if [[ -z "$MODE" ]]; then
  printf 'Usage:\n' >&2
  printf '  %s <trellis-project> delete <snapshot-name>\n' "$0" >&2
  printf '  %s <trellis-project> keep-latest <count>\n' "$0" >&2
  exit 1
fi

case "$MODE" in
  delete)
    if [[ -z "$VALUE" ]]; then
      printf 'Missing snapshot name for delete mode\n' >&2
      exit 1
    fi
    SNAPSHOT_DIR="$BACKUP_ROOT/$VALUE"
    if [[ ! -d "$SNAPSHOT_DIR" ]]; then
      printf 'Backup snapshot does not exist: %s\n' "$SNAPSHOT_DIR" >&2
      exit 1
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
      printf '[dry-run] Would delete snapshot %s\n' "$SNAPSHOT_DIR"
      exit 0
    fi

    rm -rf "$SNAPSHOT_DIR"
    printf 'Deleted snapshot %s\n' "$SNAPSHOT_DIR"
    ;;

  keep-latest)
    if [[ -z "$VALUE" ]]; then
      printf 'Missing count for keep-latest mode\n' >&2
      exit 1
    fi

    python3 - "$BACKUP_ROOT" "$VALUE" "$DRY_RUN" <<'PY'
import os
import shutil
import sys

root = sys.argv[1]
keep = int(sys.argv[2])
dry_run = sys.argv[3] == '1'

entries = []
for name in sorted(os.listdir(root), reverse=True):
    path = os.path.join(root, name)
    if os.path.isdir(path):
        entries.append((name, path))

if keep < 0:
    raise SystemExit('keep-latest count must be >= 0')

if len(entries) <= keep:
    print(f'Nothing to prune under {root}; snapshot count={len(entries)}, keep={keep}')
    raise SystemExit(0)

for name, path in entries[keep:]:
    if dry_run:
        print(f'[dry-run] Would delete snapshot {path}')
    else:
        shutil.rmtree(path)
        print(f'Deleted snapshot {path}')
PY
    ;;

  *)
    printf 'Unknown mode: %s\n' "$MODE" >&2
    printf 'Supported modes: delete, keep-latest\n' >&2
    exit 1
    ;;
esac
