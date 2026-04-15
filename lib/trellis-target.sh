#!/usr/bin/env bash

require_adapter_metadata() {
  if [[ ! -f "$ADAPTER_JSON" ]]; then
    printf 'Missing adapter metadata: %s\n' "$ADAPTER_JSON" >&2
    exit 1
  fi
}

adapter_json_value() {
  local key_path="$1"
  python3 - "$ADAPTER_JSON" "$key_path" <<'PY' | tr -d '\r'
import json
import sys

data = json.load(open(sys.argv[1], encoding='utf-8'))
for part in sys.argv[2].split('.'):
    data = data[part]
if isinstance(data, (dict, list)):
    raise SystemExit(f'Expected scalar value at {sys.argv[2]}')
print(data)
PY
}

adapter_json_lines() {
  local key_path="$1"
  python3 - "$ADAPTER_JSON" "$key_path" <<'PY' | tr -d '\r'
import json
import sys

data = json.load(open(sys.argv[1], encoding='utf-8'))
for part in sys.argv[2].split('.'):
    data = data[part]
if not isinstance(data, list):
    raise SystemExit(f'Expected list value at {sys.argv[2]}')
for item in data:
    print(item)
PY
}

load_adapter_core_metadata() {
  require_adapter_metadata
  ADAPTER_NAME=$(adapter_json_value "name")
  ADAPTER_VERSION=$(adapter_json_value "version")
  SNAPSHOT_METADATA_FILE=$(adapter_json_value "snapshotMetadataFile")
  BACKUP_ROOT_REL=$(adapter_json_value "conflictPolicy.backupRoot")
  MIN_VERSION=$(adapter_json_value "compatibility.minVersion")
}

load_adapter_installed_paths() {
  require_adapter_metadata
  INSTALLED_PATHS=$(adapter_json_lines "installedPaths")
}

load_adapter_patched_paths() {
  require_adapter_metadata
  PATCHED_PATHS=$(adapter_json_lines "patchedPaths")
}

load_adapter_patch_metadata() {
  require_adapter_metadata
  load_adapter_patched_paths
  START_INTEROP_PATH=$(adapter_json_value "patchConfig.startInterop.path")
  START_INTEROP_MARKER_START=$(adapter_json_value "patchConfig.startInterop.markerStart")
  START_INTEROP_MARKER_END=$(adapter_json_value "patchConfig.startInterop.markerEnd")
}

render_start_interop_block() {
  printf '%s\n' "$START_INTEROP_MARKER_START"
  printf '%s\n' '### Adapter interoperability: trellis-sp-local'
  printf '\n'
  printf '%s\n' 'If the `trellis-sp-local` adapter is installed, `/trellis-sp:brainstorm` satisfies the brainstorm phase for complex tasks in the adapter flow after `/trellis:start`.'
  printf '\n'
  printf '%s\n' '- Do not redirect the user back to `/trellis:brainstorm` once the adapter path is chosen.'
  printf '%s\n' '- For resume routing, inspect the candidate task `task.json` and check `meta.trellis_sp.managed` before choosing between Trellis-native flow and adapter flow.'
  printf '%s\n' '- Current-task flow: if `get_context.py` shows a current task and that task has `meta.trellis_sp.managed=true`, explicitly tell the user it is a Superpowers-managed task before continuing.'
  printf '%s\n' '- Manual-selection flow: if there is no `.trellis/.current-task` and the user selects a task to continue, read the selected task `task.json` and check `meta.trellis_sp.managed` before choosing the continuation flow.'
  printf '%s\n' '- Managed parent task: describe it as a Superpowers-managed parent task, read its `prd.md` plus any task-local `info.md`, then continue with the next adapter-native step: usually `/trellis-sp:specify`, `/trellis-sp:clarify`, `/trellis-sp:plan`, or `/trellis-sp:execute` depending on readiness.'
  printf '%s\n' '- Managed child task: describe it as a Superpowers-managed child task created for staged execution, read the child `prd.md` plus the parent `prd.md` and parent `info.md`, then resume it with `/trellis-sp:execute` child-loop semantics rather than treating it as a plain standalone Trellis task.'
  printf '%s\n' '- Child-task resume template: finish the active child implementation/check/debug loop first, do not skip directly to sibling tasks, and only return to the parent task for the parent-level final `check` after the child checkpoint is clean.'
  printf '%s\n' '- Parent-task resume template: if the parent task is already planning-ready, resume with `/trellis-sp:plan` or `/trellis-sp:execute`; otherwise continue `/trellis-sp:specify` or `/trellis-sp:clarify` before planning.'
  printf '%s\n' '- Unmarked tasks: fall back to the standard Trellis continue behavior.'
  printf '%s\n' '- Continue through the adapter flow:'
  printf '%s\n' '  - `/trellis-sp:brainstorm`'
  printf '%s\n' '  - then usually `/trellis-sp:specify`'
  printf '%s\n' '  - `/trellis-sp:clarify` only if high-value ambiguities remain'
  printf '%s\n' '  - `/trellis-sp:plan` when the task is already planning-ready or has been made planning-ready by `/trellis-sp:specify` or `/trellis-sp:clarify`'
  printf '%s\n' '    - this step should decompose broad work into atomic child tasks when staged delivery is needed'
  printf '%s\n' '  - `/trellis-sp:execute`'
  printf '%s\n' '    - this step should execute those child tasks progressively with Trellis review checkpoints'
  printf '%s\n' '  - after `/trellis-sp:execute`, restore the parent task and require a clean parent-level final `check` before handing off to `/trellis:finish-work`'
  printf '%s\n' '- Do not treat child tasks as independently ready for `/trellis:finish-work`; finish-work belongs to the parent task only.'
  printf '%s\n' '- In this adapter flow, formal research must use the Trellis research agent with explicit `subagent_type: "research"`.'
  printf '%s\n' "$START_INTEROP_MARKER_END"
}

trellis_target_hint() {
  printf 'Expected a real Trellis project initialized with `trellis init`.\n' >&2
}

require_real_trellis_project() {
  local target_dir="$1"

  TRELLIS_DIR="$target_dir/.trellis"
  TRELLIS_VERSION_FILE="$TRELLIS_DIR/.version"
  TRELLIS_TEMPLATE_HASHES_FILE="$TRELLIS_DIR/.template-hashes.json"

  if [[ ! -d "$TRELLIS_DIR" ]]; then
    printf 'Target is not a Trellis project: %s\n' "$target_dir" >&2
    trellis_target_hint
    exit 1
  fi

  if [[ ! -f "$TRELLIS_VERSION_FILE" ]]; then
    printf 'Missing Trellis version file: %s\n' "$TRELLIS_VERSION_FILE" >&2
    trellis_target_hint
    exit 1
  fi

  TRELLIS_VERSION="$(<"$TRELLIS_VERSION_FILE")"
  TRELLIS_VERSION="${TRELLIS_VERSION//$'\r'/}"
  TRELLIS_VERSION="${TRELLIS_VERSION//$'\n'/}"
  if [[ -z "$TRELLIS_VERSION" ]]; then
    printf 'Trellis version file is empty: %s\n' "$TRELLIS_VERSION_FILE" >&2
    trellis_target_hint
    exit 1
  fi

  if [[ -f "$TRELLIS_TEMPLATE_HASHES_FILE" ]]; then
    TRELLIS_TEMPLATE_HASHES_PRESENT=1
  else
    TRELLIS_TEMPLATE_HASHES_PRESENT=0
  fi
}

assert_trellis_version_at_least() {
  local current_version="$1"
  local minimum_version="$2"

  python3 - "$current_version" "$minimum_version" <<'PY'
import re
import sys

def parse(version: str):
    m = re.match(r'^(\d+)\.(\d+)\.(\d+)(?:-([A-Za-z]+)\.(\d+))?$', version)
    if not m:
        raise SystemExit(f'Unsupported version format: {version}')
    major, minor, patch, pre_label, pre_num = m.groups()
    pre_order = {'alpha': 0, 'beta': 1, 'rc': 2}
    if pre_label is None:
        pre_key = (3, 0)
    else:
        pre_key = (pre_order.get(pre_label, -1), int(pre_num))
    return (int(major), int(minor), int(patch), pre_key)

current = parse(sys.argv[1])
minimum = parse(sys.argv[2])
if current < minimum:
    raise SystemExit(f'Trellis version {sys.argv[1]} is below supported minimum {sys.argv[2]}')
PY
}
