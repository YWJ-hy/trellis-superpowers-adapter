#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_JSON="$SCRIPT_DIR/adapter.json"
TARGET_ARG="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"
SNAPSHOT_NAME="${2:-}"

if [[ ! -f "$ADAPTER_JSON" ]]; then
  printf 'Missing adapter metadata: %s\n' "$ADAPTER_JSON" >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR/.trellis" ]]; then
  printf 'Target is not a Trellis project: %s\n' "$TARGET_DIR" >&2
  printf 'Expected a real Trellis project initialized with `trellis init`.\n' >&2
  exit 1
fi

BACKUP_ROOT_REL=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["conflictPolicy"]["backupRoot"])' "$ADAPTER_JSON")
SNAPSHOT_METADATA_FILE=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["snapshotMetadataFile"])' "$ADAPTER_JSON")
BACKUP_ROOT="$TARGET_DIR/$BACKUP_ROOT_REL"

if [[ ! -d "$BACKUP_ROOT" ]]; then
  printf 'No backup snapshots found under %s\n' "$BACKUP_ROOT"
  exit 0
fi

if [[ -z "$SNAPSHOT_NAME" ]]; then
  python3 - "$BACKUP_ROOT" "$SNAPSHOT_METADATA_FILE" <<'PY'
import json
import os
import sys

root = sys.argv[1]
metadata_name = sys.argv[2]
entries = []
for name in sorted(os.listdir(root)):
    path = os.path.join(root, name)
    if not os.path.isdir(path):
        continue
    file_count = 0
    metadata = None
    for current_root, _, files in os.walk(path):
        for filename in files:
            rel = os.path.relpath(os.path.join(current_root, filename), path)
            if rel == metadata_name:
                metadata = json.load(open(os.path.join(current_root, filename)))
                continue
            file_count += 1
    entries.append((name, file_count, metadata))

if not entries:
    raise SystemExit(f'No backup snapshots found under {root}')

print('Available adapter backup snapshots:')
for name, file_count, metadata in entries:
    if metadata:
        operation = metadata.get('operation', 'unknown')
        created_at = metadata.get('createdAt', 'unknown')
        print(f'- {name} ({file_count} file(s), {operation}, createdAt={created_at})')
    else:
        print(f'- {name} ({file_count} file(s), legacy metadata)')
PY
  exit 0
fi

SNAPSHOT_DIR="$BACKUP_ROOT/$SNAPSHOT_NAME"
if [[ ! -d "$SNAPSHOT_DIR" ]]; then
  printf 'Backup snapshot does not exist: %s\n' "$SNAPSHOT_DIR" >&2
  exit 1
fi

python3 - "$SNAPSHOT_DIR" "$ADAPTER_JSON" "$SNAPSHOT_METADATA_FILE" <<'PY'
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
    raise SystemExit(f'Snapshot contains no adapter files: {snapshot_dir}')

print(f'Snapshot: {os.path.basename(snapshot_dir)}')
if metadata:
    print(f'  operation: {metadata.get("operation", "unknown")}')
    print(f'  createdBy: {metadata.get("createdBy", "unknown")}')
    print(f'  createdAt: {metadata.get("createdAt", "unknown")}')
    print(f'  trellisVersion: {metadata.get("trellisVersion", "unknown")}')
    print(f'  adapterVersion: {metadata.get("adapterVersion", "unknown")}')
else:
    print('  metadata: legacy snapshot (no snapshot.json)')

for rel in sorted(found):
    print(f'- {rel}')
PY
