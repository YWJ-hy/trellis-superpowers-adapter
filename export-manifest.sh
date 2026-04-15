#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_JSON="$SCRIPT_DIR/adapter.json"
HELPER="$SCRIPT_DIR/lib/trellis-target.sh"
TARGET_ARG="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"
OUTPUT_PATH="${2:-}"

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

VERIFY_OUTPUT=""
VERIFY_STATUS="passed"
if ! VERIFY_OUTPUT=$("$SCRIPT_DIR/verify.sh" "$TARGET_DIR" 2>&1); then
  VERIFY_STATUS="failed"
fi

MANIFEST_JSON=$(python3 - "$ADAPTER_JSON" "$TARGET_DIR" "$TRELLIS_VERSION" "$VERIFY_STATUS" "$BACKUP_ROOT" "$SNAPSHOT_METADATA_FILE" "$TRELLIS_VERSION_FILE" "$TRELLIS_TEMPLATE_HASHES_FILE" "$TRELLIS_TEMPLATE_HASHES_PRESENT" <<'PY' | tr -d '\r'
import json
import os
import sys

adapter_json_path, target_dir, trellis_version, verify_status, backup_root, metadata_name, version_file, template_hashes_file, template_hashes_present = sys.argv[1:]
adapter = json.load(open(adapter_json_path, encoding='utf-8'))
installed_paths = adapter["installedPaths"]
patched_paths = adapter.get("patchedPaths", [])
patch_config = adapter.get("patchConfig", {}).get("startInterop", {})
marker_start = patch_config.get("markerStart")
marker_end = patch_config.get("markerEnd")

installed_files = []
missing_files = []
for rel in installed_paths:
    if os.path.isfile(os.path.join(target_dir, rel)):
        installed_files.append(rel)
    else:
        missing_files.append(rel)

patched_files = []
missing_patched_files = []
patch_states = []
for rel in patched_paths:
    full = os.path.join(target_dir, rel)
    if not os.path.isfile(full):
        missing_patched_files.append(rel)
        patch_states.append({"path": rel, "status": "missing-file"})
        continue
    patched_files.append(rel)
    text = open(full, encoding='utf-8').read()
    start_count = text.count(marker_start) if marker_start else 0
    end_count = text.count(marker_end) if marker_end else 0
    if start_count == 1 and end_count == 1:
        status = "patched"
    elif start_count == 0 and end_count == 0:
        status = "unpatched"
    else:
        status = "drifted"
    patch_states.append({
        "path": rel,
        "status": status,
        "markerStartCount": start_count,
        "markerEndCount": end_count,
    })

snapshots = []
if os.path.isdir(backup_root):
    for name in sorted(os.listdir(backup_root), reverse=True):
        path = os.path.join(backup_root, name)
        if not os.path.isdir(path):
            continue
        files = []
        metadata = None
        for root, _, file_names in os.walk(path):
            for filename in file_names:
                rel = os.path.relpath(os.path.join(root, filename), path)
                if rel == metadata_name:
                    metadata = json.load(open(os.path.join(root, filename), encoding='utf-8'))
                else:
                    files.append(rel)
        snapshots.append({
            "name": name,
            "fileCount": len(files),
            "metadata": metadata,
            "files": sorted(files),
        })

manifest = {
    "adapter": {
        "name": adapter["name"],
        "version": adapter["version"],
    },
    "target": {
        "path": target_dir,
        "trellisVersion": trellis_version,
        "versionSource": version_file,
        "templateHashesPath": template_hashes_file,
        "templateHashesPresent": template_hashes_present == "1",
    },
    "installState": {
        "installedFileCount": len(installed_files),
        "missingFileCount": len(missing_files),
        "installedFiles": installed_files,
        "missingFiles": missing_files,
        "patchedFileCount": len(patched_files),
        "missingPatchedFileCount": len(missing_patched_files),
        "patchedFiles": patched_files,
        "missingPatchedFiles": missing_patched_files,
    },
    "patchState": {
        "managedPatchedPaths": patched_paths,
        "states": patch_states,
    },
    "verify": {
        "status": verify_status,
    },
    "backups": {
        "root": backup_root,
        "snapshotCount": len(snapshots),
        "snapshots": snapshots,
    },
}

print(json.dumps(manifest, indent=2))
PY
)

if [[ -n "$OUTPUT_PATH" ]]; then
  printf '%s\n' "$MANIFEST_JSON" > "$OUTPUT_PATH"
  printf 'Exported manifest to %s\n' "$OUTPUT_PATH"
else
  printf '%s\n' "$MANIFEST_JSON"
fi
