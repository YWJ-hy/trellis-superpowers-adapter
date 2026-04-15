#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
PROJECT_DIR="$TMP_ROOT/real-project"
BROKEN_DIR="$TMP_ROOT/missing-version-project"
EXPECTED_VERSION="0.4.0-beta.10"
START_MARKER='<!-- trellis-superpowers-adapter:start-interop:start -->'

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

mkdir -p "$PROJECT_DIR/.trellis" "$PROJECT_DIR/.claude/commands/trellis"
printf '%s\n' "$EXPECTED_VERSION" > "$PROJECT_DIR/.trellis/.version"
printf '{}\n' > "$PROJECT_DIR/.trellis/.template-hashes.json"
cat > "$PROJECT_DIR/.claude/commands/trellis/start.md" <<'EOF'
# Start Session

## Complex Task - Brainstorm First

Follow `/trellis:brainstorm` before implementation.
EOF

BOOTSTRAP_OUTPUT=$("$ADAPTER_DIR/manage.sh" bootstrap "$PROJECT_DIR" 2>&1) || {
  printf '%s\n' "$BOOTSTRAP_OUTPUT" >&2
  fail 'bootstrap failed for real-project target with start interop patching'
}

grep -q "Installed Trellis-Superpowers adapter into $PROJECT_DIR" <<< "$BOOTSTRAP_OUTPUT" || fail 'bootstrap did not install into the real-project target'
grep -q "Detected Trellis version: $EXPECTED_VERSION" <<< "$BOOTSTRAP_OUTPUT" || fail 'bootstrap did not read Trellis version from .trellis/.version'
if grep -q 'Missing Trellis package metadata' <<< "$BOOTSTRAP_OUTPUT"; then
  fail 'bootstrap regressed to packages/cli/package.json detection'
fi

grep -q "$START_MARKER" "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'bootstrap did not patch start.md with adapter interop block'
grep -q 'inspect the candidate task `task.json` and check `meta.trellis_sp.managed`' "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'patched start.md did not include trellis_sp metadata resume routing'
grep -q 'Current-task flow:' "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'patched start.md did not document current-task resume routing'
grep -q 'Manual-selection flow:' "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'patched start.md did not document manual-selection resume routing'
grep -q 'Managed child task:' "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'patched start.md did not describe child-task adapter resume behavior'
grep -q 'read its `prd.md` plus any task-local `info.md`' "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'patched start.md did not describe parent-task resume context'
grep -q 'read the child `prd.md` plus the parent `prd.md` and parent `info.md`' "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'patched start.md did not describe child-task resume context'
grep -q 'Child-task resume template:' "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'patched start.md did not include child-task resume template'
grep -q 'Parent-task resume template:' "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'patched start.md did not include parent-task resume template'
grep -q 'then usually `/trellis-sp:specify`' "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'patched start.md did not recommend specify as the default next step after brainstorm'
grep -q '`/trellis-sp:clarify` only if high-value ambiguities remain' "$PROJECT_DIR/.claude/commands/trellis/start.md" || fail 'patched start.md did not keep clarify conditional'
[[ -f "$PROJECT_DIR/.claude/scripts/trellis-sp-task-meta.py" ]] || fail 'bootstrap did not install trellis-sp task metadata writer'
python3 "$PROJECT_DIR/.claude/scripts/trellis-sp-task-meta.py" --repo-root "$PROJECT_DIR" ".trellis/tasks/04-14-parent" --role parent --phase plan >/dev/null 2>&1 && fail 'metadata writer unexpectedly succeeded for missing task'
mkdir -p "$PROJECT_DIR/.trellis/tasks/04-14-parent" "$PROJECT_DIR/.trellis/tasks/04-14-child"
cat > "$PROJECT_DIR/.trellis/tasks/04-14-parent/task.json" <<'EOF'
{
  "title": "Parent task",
  "children": ["04-14-child"],
  "meta": {}
}
EOF
cat > "$PROJECT_DIR/.trellis/tasks/04-14-child/task.json" <<'EOF'
{
  "title": "Child task",
  "parent": "04-14-parent",
  "meta": {}
}
EOF
python3 "$PROJECT_DIR/.claude/scripts/trellis-sp-task-meta.py" --repo-root "$PROJECT_DIR" ".trellis/tasks/04-14-parent" --role parent --phase plan >/dev/null || fail 'metadata writer failed for parent task fixture'
python3 "$PROJECT_DIR/.claude/scripts/trellis-sp-task-meta.py" --repo-root "$PROJECT_DIR" ".trellis/tasks/04-14-child" --role child --phase execute >/dev/null || fail 'metadata writer failed for child task fixture'
python3 - "$PROJECT_DIR/.trellis/tasks/04-14-parent/task.json" "$PROJECT_DIR/.trellis/tasks/04-14-child/task.json" <<'PY'
import json
import sys
parent_path, child_path = sys.argv[1:3]
parent = json.load(open(parent_path, encoding='utf-8'))
child = json.load(open(child_path, encoding='utf-8'))
parent_meta = parent.get('meta', {}).get('trellis_sp', {})
child_meta = child.get('meta', {}).get('trellis_sp', {})
assert parent_meta.get('managed') is True
assert parent_meta.get('role') == 'parent'
assert parent_meta.get('workflow_version') == 1
assert parent_meta.get('last_phase') == 'plan'
assert child_meta.get('managed') is True
assert child_meta.get('role') == 'child'
assert child_meta.get('workflow_version') == 1
assert child_meta.get('last_phase') == 'execute'
assert parent.get('children') == ['04-14-child']
assert child.get('parent') == '04-14-parent'
PY

[[ ! -e "$PROJECT_DIR/packages/cli/package.json" ]] || fail 'test fixture unexpectedly contains packages/cli/package.json'

MANIFEST_JSON=$("$ADAPTER_DIR/manage.sh" export-manifest "$PROJECT_DIR") || fail 'export-manifest failed for real-project target without packages/cli/package.json'
python3 - "$MANIFEST_JSON" "$PROJECT_DIR/.trellis/.version" "$PROJECT_DIR/.trellis/.template-hashes.json" "$EXPECTED_VERSION" <<'PY'
import json
import sys

manifest = json.loads(sys.argv[1])
version_source = sys.argv[2]
template_hashes_path = sys.argv[3]
expected_version = sys.argv[4]

assert manifest['target']['trellisVersion'] == expected_version
assert manifest['target']['versionSource'] == version_source
assert manifest['target']['templateHashesPath'] == template_hashes_path
assert manifest['target']['templateHashesPresent'] is True
assert manifest['verify']['status'] == 'passed'
assert manifest['installState']['missingFileCount'] == 0
assert manifest['patchState']['states'][0]['status'] == 'patched'
PY

"$ADAPTER_DIR/manage.sh" uninstall "$PROJECT_DIR" >/dev/null || fail 'uninstall failed for real-project target'
if grep -q "$START_MARKER" "$PROJECT_DIR/.claude/commands/trellis/start.md"; then
  fail 'uninstall did not remove start interop block'
fi

mkdir -p "$BROKEN_DIR/.trellis"
if BROKEN_OUTPUT=$("$ADAPTER_DIR/manage.sh" verify "$BROKEN_DIR" 2>&1); then
  printf '%s\n' "$BROKEN_OUTPUT" >&2
  fail 'verify unexpectedly passed when .trellis/.version is missing'
fi

grep -q 'Missing Trellis version file:' <<< "$BROKEN_OUTPUT" || fail 'missing-version failure did not explain the missing .trellis/.version file'
grep -q 'Expected a real Trellis project initialized with `trellis init`.' <<< "$BROKEN_OUTPUT" || fail 'missing-version failure did not explain the expected real-project target shape'

printf 'real-project target regression passed\n'
