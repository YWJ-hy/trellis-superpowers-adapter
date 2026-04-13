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

assert_contains() {
  local file="$1"
  local needle="$2"
  local description="$3"

  if ! grep -Fq -- "$needle" "$file"; then
    printf 'Missing expected marker (%s) in %s: %s\n' "$description" "$file" "$needle" >&2
    exit 1
  fi
}

assert_not_regex() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if grep -Eq "$pattern" "$file"; then
    printf 'Unexpected %s in %s\n' "$description" "$file" >&2
    grep -En "$pattern" "$file" >&2 || true
    exit 1
  fi
}

assert_not_regex_in_files() {
  local pattern="$1"
  local description="$2"
  shift 2

  if grep -Eq "$pattern" "$@"; then
    printf 'Unexpected %s across installed runtime files\n' "$description" >&2
    grep -En "$pattern" "$@" >&2 || true
    exit 1
  fi
}

assert_count() {
  local file="$1"
  local needle="$2"
  local expected="$3"
  local description="$4"
  local count
  count=$(python3 - "$file" "$needle" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
print(text.count(sys.argv[2]))
PY
)
  if [[ "$count" != "$expected" ]]; then
    printf 'Unexpected %s count in %s: expected %s, got %s\n' "$description" "$file" "$expected" "$count" >&2
    exit 1
  fi
}

installed_file() {
  local relative_path="$1"
  printf '%s/%s\n' "$TARGET_DIR" "$relative_path"
}

load_adapter_core_metadata
load_adapter_installed_paths
load_adapter_patch_metadata
require_real_trellis_project "$TARGET_DIR"
assert_trellis_version_at_least "$TRELLIS_VERSION" "$MIN_VERSION"
EXPECTED_FILES="$INSTALLED_PATHS"
START_FILE="$(installed_file "$START_INTEROP_PATH")"

if [[ "$DRY_RUN" == "1" ]]; then
  printf '[dry-run] Would verify adapter in %s\n' "$TARGET_DIR"
  printf '[dry-run] Expected minimum Trellis version: %s\n' "$MIN_VERSION"
  while IFS= read -r relative_path; do
    [[ -z "$relative_path" ]] && continue
    printf '[dry-run] Would check %s\n' "$TARGET_DIR/$relative_path"
  done <<< "$EXPECTED_FILES"
  printf '[dry-run] Would check patched file %s\n' "$START_FILE"
  exit 0
fi

RUNTIME_FILES=()
while IFS= read -r relative_path; do
  [[ -z "$relative_path" ]] && continue
  if [[ ! -f "$TARGET_DIR/$relative_path" ]]; then
    printf 'Missing installed file: %s\n' "$TARGET_DIR/$relative_path" >&2
    exit 1
  fi
  RUNTIME_FILES+=("$TARGET_DIR/$relative_path")
done <<< "$EXPECTED_FILES"

if [[ ! -f "$START_FILE" ]]; then
  printf 'Missing patched Trellis start command: %s\n' "$START_FILE" >&2
  exit 1
fi

BRAINSTORM_FILE="$(installed_file '.claude/commands/trellis-sp/brainstorm.md')"
SPECIFY_FILE="$(installed_file '.claude/commands/trellis-sp/specify.md')"
CLARIFY_FILE="$(installed_file '.claude/commands/trellis-sp/clarify.md')"
PLAN_FILE="$(installed_file '.claude/commands/trellis-sp/plan.md')"
EXECUTE_FILE="$(installed_file '.claude/commands/trellis-sp/execute.md')"
SKILL_FILE="$(installed_file '.claude/skills/trellis-sp-local/SKILL.md')"
META_WRITER_FILE="$(installed_file '.claude/scripts/trellis-sp-task-meta.py')"
README_FILE="$SCRIPT_DIR/README.md"
README_INTEGRATION_CN_FILE="$SCRIPT_DIR/README_INTEGRATION_CN.md"
INTEGRATION_CN_FILE="$SCRIPT_DIR/SUPERPOWERS_TRELLIS_INTEGRATION_CN.md"

assert_contains "$BRAINSTORM_FILE" 'prd.md' 'brainstorm Trellis PRD contract'
assert_contains "$BRAINSTORM_FILE" 'one question per message' 'brainstorm question discipline'
assert_contains "$BRAINSTORM_FILE" 'default next Trellis-native adapter step is `/trellis-sp:specify`' 'brainstorm specify-first handoff'
assert_contains "$BRAINSTORM_FILE" 'recommend `/trellis-sp:clarify` only when high-value ambiguities still remain' 'brainstorm conditional clarify handoff'
assert_contains "$BRAINSTORM_FILE" 'recommend `/trellis-sp:plan` only when the task is already planning-ready' 'brainstorm conditional plan handoff'
assert_contains "$BRAINSTORM_FILE" 'set it as the current task before deep brainstorming continues' 'brainstorm parent current-task activation'
assert_contains "$BRAINSTORM_FILE" 'python3 ./.trellis/scripts/task.py start <task-dir>' 'brainstorm explicit task start command'
assert_contains "$BRAINSTORM_FILE" '.trellis/.current-task' 'brainstorm current-task pointer contract'
assert_contains "$BRAINSTORM_FILE" 'meta.trellis_sp' 'brainstorm trellis_sp metadata contract'
assert_contains "$BRAINSTORM_FILE" 'managed=true' 'brainstorm trellis_sp managed marker'
assert_contains "$BRAINSTORM_FILE" 'role="parent"' 'brainstorm trellis_sp parent role marker'
assert_contains "$BRAINSTORM_FILE" 'immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase brainstorm`' 'brainstorm metadata writer command'
assert_contains "$SPECIFY_FILE" 'active Trellis task' 'specify active task requirement'
assert_contains "$SPECIFY_FILE" 'prd.md' 'specify PRD target'
assert_contains "$SPECIFY_FILE" 'meta.trellis_sp' 'specify trellis_sp metadata contract'
assert_contains "$SPECIFY_FILE" 'managed=true' 'specify trellis_sp managed marker'
assert_contains "$SPECIFY_FILE" 'role="parent"' 'specify trellis_sp parent role marker'
assert_contains "$SPECIFY_FILE" 'immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase specify`' 'specify metadata writer command'
assert_contains "$CLARIFY_FILE" 'active Trellis task' 'clarify active task requirement'
assert_contains "$CLARIFY_FILE" '## Clarifications' 'clarify section contract'
assert_contains "$CLARIFY_FILE" 'prd.md' 'clarify PRD target'
assert_contains "$PLAN_FILE" 'task-local artifacts for planning outputs' 'plan task-local output contract'
assert_contains "$PLAN_FILE" 'info.md' 'plan info.md output'
assert_contains "$PLAN_FILE" 'likely touched files' 'plan file-path thinking'
assert_contains "$PLAN_FILE" 'atomic child tasks' 'plan atomic child-task decomposition'
assert_contains "$PLAN_FILE" 'ordered atomic child tasks' 'plan ordered child-task contract'
assert_contains "$PLAN_FILE" 'keep the parent task as `.trellis/.current-task` throughout planning' 'plan keep parent current-task'
assert_contains "$PLAN_FILE" 'do not leave a newly created child task as the current task at the end of planning' 'plan no child current-task leak'
assert_contains "$PLAN_FILE" 'meta.trellis_sp' 'plan trellis_sp metadata contract'
assert_contains "$PLAN_FILE" 'role="parent"' 'plan trellis_sp parent role marker'
assert_contains "$PLAN_FILE" 'role="child"' 'plan trellis_sp child role marker'
assert_contains "$PLAN_FILE" 'advance its `last_phase` to `plan` or `execute`' 'plan trellis_sp phase advancement'
assert_contains "$PLAN_FILE" 'last_phase="execute"' 'plan trellis_sp child execute phase marker'
assert_contains "$PLAN_FILE" 'immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase plan`' 'plan parent metadata writer command'
assert_contains "$PLAN_FILE" 'run `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase execute` once the parent is ready to hand off to execution' 'plan parent execute metadata writer command'
assert_contains "$PLAN_FILE" 'immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <child-task-dir> --role child --phase execute`' 'plan child metadata writer command'
assert_contains "$PLAN_FILE" 'Recommended artifact templates' 'plan artifact template section'
assert_contains "$PLAN_FILE" 'Parent task `info.md`' 'plan parent info template'
assert_contains "$PLAN_FILE" 'Child task `prd.md`' 'plan child prd template'
assert_contains "$PLAN_FILE" 'Child task context minimum' 'plan child context template'
assert_contains "$EXECUTE_FILE" 'Trellis-compatible subagent types' 'execute Trellis subagent routing'
assert_contains "$EXECUTE_FILE" 'Final verification must go through Trellis `check`' 'execute final verification contract'
assert_contains "$EXECUTE_FILE" 'stop on blockers instead of guessing' 'execute blocker discipline'
assert_contains "$EXECUTE_FILE" 'execute child tasks in their planned order' 'execute sequential child-task flow'
assert_contains "$EXECUTE_FILE" 'python3 ./.trellis/scripts/task.py start <child-task-dir>' 'execute explicit child task start command'
assert_contains "$EXECUTE_FILE" '.trellis/.current-task' 'execute current-task pointer contract'
assert_contains "$EXECUTE_FILE" 'restore `.trellis/.current-task` to the parent task' 'execute restore parent current-task'
assert_contains "$EXECUTE_FILE" 'Review checkpoints are mandatory' 'execute review checkpoint contract'
assert_contains "$EXECUTE_FILE" 'parent-level final `check`' 'execute parent final check'
assert_contains "$EXECUTE_FILE" 'Recommended execution checklist' 'execute checklist section'
assert_contains "$EXECUTE_FILE" 'child task `prd.md` is still accurate' 'execute child readiness checklist'
assert_contains "$EXECUTE_FILE" 'every ordered child task completed' 'execute final workflow checklist'
assert_contains "$META_WRITER_FILE" 'Update task.json meta.trellis_sp for adapter-managed tasks.' 'metadata writer description'
assert_contains "$META_WRITER_FILE" 'choices=("parent", "child")' 'metadata writer role choices'
assert_contains "$META_WRITER_FILE" 'choices=("brainstorm", "specify", "clarify", "plan", "execute")' 'metadata writer phase choices'
assert_contains "$META_WRITER_FILE" 'Updated trellis_sp metadata:' 'metadata writer success output'
assert_contains "$SKILL_FILE" 'Superpowers installation is not required at runtime' 'skill no-plugin runtime contract'
assert_contains "$SKILL_FILE" 'after `/trellis-sp:brainstorm`, the default next step is `/trellis-sp:specify`' 'skill specify-first handoff'
assert_contains "$SKILL_FILE" 'use `/trellis-sp:clarify` only if high-value ambiguities remain' 'skill conditional clarify handoff'
assert_contains "$SKILL_FILE" 'use `/trellis-sp:plan` when the task is already planning-ready' 'skill conditional plan handoff'
assert_contains "$SKILL_FILE" 'creates a Trellis-native atomic child-task workflow' 'skill atomic plan workflow'
assert_contains "$SKILL_FILE" 'runs those atomic child tasks progressively' 'skill atomic execute workflow'
assert_contains "$SKILL_FILE" 'route real implementation/review work through Trellis-compatible subagents' 'skill Trellis subagent routing'

assert_not_regex_in_files 'superpowers:|install or enable the Superpowers plugin|install Superpowers|enable Superpowers plugin' 'Superpowers runtime dependency language' "${RUNTIME_FILES[@]}"
assert_not_regex "$BRAINSTORM_FILE" 'write design doc|docs/superpowers/specs/YYYY-MM-DD|docs/superpowers/plans/YYYY-MM-DD' 'raw Superpowers external artifact behavior'
assert_not_regex "$SPECIFY_FILE" 'SPECIFY_FEATURE_DIRECTORY|FEATURE_DIR|\.specify/feature\.json' 'spec-kit workspace artifacts'
assert_not_regex "$CLARIFY_FILE" 'SPECIFY_FEATURE_DIRECTORY|FEATURE_DIR|\.specify/feature\.json' 'spec-kit workspace artifacts'
assert_not_regex "$PLAN_FILE" 'Save plans to:|write design doc|docs/superpowers/specs/YYYY-MM-DD|docs/superpowers/plans/YYYY-MM-DD' 'raw Superpowers external artifact behavior'
assert_not_regex "$EXECUTE_FILE" 'Save plans to:|write design doc|docs/superpowers/specs/YYYY-MM-DD|docs/superpowers/plans/YYYY-MM-DD' 'raw Superpowers external artifact behavior'

assert_count "$START_FILE" "$START_INTEROP_MARKER_START" "1" 'start interop begin marker'
assert_count "$START_FILE" "$START_INTEROP_MARKER_END" "1" 'start interop end marker'
assert_contains "$START_FILE" '/trellis-sp:brainstorm` satisfies the brainstorm phase' 'start interop brainstorm equivalence'
assert_contains "$START_FILE" 'Do not redirect the user back to `/trellis:brainstorm`' 'start interop no-redirect rule'
assert_contains "$START_FILE" 'inspect the candidate task `task.json` and check `meta.trellis_sp.managed`' 'start interop metadata routing rule'
assert_contains "$START_FILE" 'Current-task flow:' 'start interop current-task flow'
assert_contains "$START_FILE" 'Manual-selection flow:' 'start interop manual-selection flow'
assert_contains "$START_FILE" 'Managed parent task:' 'start interop managed parent rule'
assert_contains "$START_FILE" 'read its `prd.md` plus any task-local `info.md`' 'start interop parent resume context'
assert_contains "$START_FILE" 'Managed child task:' 'start interop managed child rule'
assert_contains "$START_FILE" 'read the child `prd.md` plus the parent `prd.md` and parent `info.md`' 'start interop child resume context'
assert_contains "$START_FILE" 'Child-task resume template:' 'start interop child resume template'
assert_contains "$START_FILE" 'Parent-task resume template:' 'start interop parent resume template'
assert_contains "$START_FILE" 'Unmarked tasks: fall back to the standard Trellis continue behavior.' 'start interop unmarked fallback rule'
assert_contains "$START_FILE" 'then usually `/trellis-sp:specify`' 'start interop specify-first handoff'
assert_contains "$START_FILE" '`/trellis-sp:clarify` only if high-value ambiguities remain' 'start interop conditional clarify handoff'
assert_contains "$START_FILE" '`/trellis-sp:plan` when the task is already planning-ready or has been made planning-ready by `/trellis-sp:specify` or `/trellis-sp:clarify`' 'start interop conditional plan handoff'
assert_contains "$START_FILE" 'decompose broad work into atomic child tasks' 'start interop atomic decomposition'
assert_contains "$START_FILE" 'execute those child tasks progressively with Trellis review checkpoints' 'start interop progressive execution'
assert_contains "$START_FILE" 'subagent_type: "research"' 'start interop research routing'

assert_contains "$README_FILE" 'Current-task rules in this adapter flow:' 'README current-task rules section'
assert_contains "$README_FILE" 'set `.trellis/.current-task` to that parent before handing off to `/trellis-sp:specify`' 'README brainstorm parent activation'
assert_contains "$README_FILE" 'keep the parent task as the current task while creating or updating child tasks' 'README plan keeps parent current'
assert_contains "$README_FILE" 'switch `.trellis/.current-task` to each child task before running child-local `implement` / `check` / `debug`' 'README execute child current-task switch'
assert_contains "$README_INTEGRATION_CN_FILE" 'current task 规则需要明确理解' 'README CN current-task rules section'
assert_contains "$README_INTEGRATION_CN_FILE" '把 `.trellis/.current-task` 设为 parent task' 'README CN brainstorm parent activation'
assert_contains "$README_INTEGRATION_CN_FILE" '`.trellis/.current-task` 仍应保持指向 parent task' 'README CN plan keeps parent current'
assert_contains "$README_INTEGRATION_CN_FILE" '先把 `.trellis/.current-task` 切到该 child' 'README CN execute child current-task switch'
assert_contains "$INTEGRATION_CN_FILE" '应确保 parent task 被设为 current task' 'integration doc brainstorm parent current-task'
assert_contains "$INTEGRATION_CN_FILE" 'planning 期间 current task 仍保持 parent' 'integration doc plan keeps parent current'
assert_contains "$INTEGRATION_CN_FILE" '执行 child 时切到 child，最终校验前再切回 parent' 'integration doc execute current-task switching'

printf 'Adapter verification passed for %s\n' "$TARGET_DIR"
printf 'Detected Trellis version: %s\n' "$TRELLIS_VERSION"
printf 'Minimum supported version: %s\n' "$MIN_VERSION"
if [[ "$TRELLIS_TEMPLATE_HASHES_PRESENT" != "1" ]]; then
  printf 'Warning: Trellis template hashes are missing at %s\n' "$TRELLIS_TEMPLATE_HASHES_FILE"
fi
printf 'Verified commands:\n'
printf '  /trellis-sp:brainstorm\n'
printf '  /trellis-sp:specify\n'
printf '  /trellis-sp:clarify\n'
printf '  /trellis-sp:plan\n'
printf '  /trellis-sp:execute\n'
printf 'Verified patched interop:\n'
printf '  %s\n' "$START_INTEROP_PATH"
