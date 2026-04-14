# Trellis-Superpowers Adapter

This directory is a pluggable overlay that vendors Superpowers-inspired workflow guidance locally and adds Trellis-native task-spec entrypoints to a Trellis project without modifying Trellis core files.

The runtime contract is intentionally self-contained:

- users do **not** need to install the Superpowers plugin
- adapter commands do **not** invoke `superpowers:*` skills at runtime
- Trellis remains the source of truth for tasks, specs, workspace state, and final verification
- Superpowers is used only as a prompt-method source that has been adapted into the overlay

This design avoids hook conflicts between Trellis and a globally installed Superpowers setup.

## What it installs

- `.claude/commands/trellis-sp/brainstorm.md`
- `.claude/commands/trellis-sp/specify.md`
- `.claude/commands/trellis-sp/clarify.md`
- `.claude/commands/trellis-sp/plan.md`
- `.claude/commands/trellis-sp/execute.md`
- `.claude/skills/trellis-sp-local/SKILL.md`

## Command map

- `/trellis-sp:brainstorm` → local brainstorming discipline adapted from Trellis + Superpowers
- `/trellis-sp:specify` → Trellis-native task PRD spec authoring
- `/trellis-sp:clarify` → Trellis-native task PRD clarification
- `/trellis-sp:plan` → local planning discipline adapted from Superpowers + Trellis-native atomic child-task decomposition and task-local execution contracts
- `/trellis-sp:execute` → local execution discipline adapted from Superpowers + progressive child-task execution through Trellis-compatible subagent routing

## Compatibility

- Expected target: a normal project initialized by the global `@mindfoldhq/trellis` CLI via `trellis init`
- Required Trellis markers: `.trellis/` and `.trellis/.version`
- Recommended Trellis marker: `.trellis/.template-hashes.json`
- Minimum supported version: `0.4.0-beta.8`
- Tested version: `0.4.0-beta.10`

## Method sources

### Trellis-native sources

- `Trellis/.claude/commands/trellis/brainstorm.md`
- `Trellis/.claude/commands/trellis/start.md`

### Superpowers sources adapted locally

- `superpowers/skills/brainstorming/SKILL.md`
- `superpowers/skills/writing-plans/SKILL.md`
- `superpowers/skills/executing-plans/SKILL.md`

The adapter does not execute those upstream skills at runtime. It vendors the useful workflow discipline into the overlay commands.

## Spec-kit-derived pieces

The adapter as a whole is not a spec-kit integration layer, but two command surfaces are explicitly adapted from spec-kit:

- `/trellis-sp:specify` is adapted from spec-kit's `specify` workflow and spec template structure.
- `/trellis-sp:clarify` is adapted from spec-kit's `clarify` workflow, ambiguity taxonomy, and incremental clarification loop.
- In both cases, the persistence model is intentionally rewritten for Trellis: the active task `prd.md` is the single task-level source of truth, and the adapter does **not** create `specs/` or `.specify/` workspace state.

The following parts are **not** spec-kit workspace integrations:

- `/trellis-sp:brainstorm`
- `/trellis-sp:plan`
- `/trellis-sp:execute`
- adapter lifecycle scripts such as `install.sh`, `verify.sh`, `bootstrap.sh`, and `release-check.sh`

## Minimal integration guide

Use this flow when you have installed the latest Trellis into a real project and want to insert this adapter there.

### 1. Prepare the target project

Confirm the target project is already a Trellis project created by running `trellis init` inside a normal repo/project. It should have:

- `.trellis/`
- `.trellis/.version`
- ideally `.trellis/.template-hashes.json`

If `.trellis/.version` is missing, the adapter will refuse to install because it cannot determine the installed Trellis version.

### 2. Run bootstrap from this adapter repo

From `trellis-superpowers-adapter/`:

```bash
./bootstrap.sh /path/to/your/real-project
```

Or equivalently:

```bash
./manage.sh bootstrap /path/to/your/real-project
```

What bootstrap does:

- if the adapter is absent, it installs and verifies it
- if the adapter is already healthy, it only verifies it
- if the adapter is partial or unhealthy, it stops and tells you to inspect with doctor / install / list-backups

### 3. Verify the install

Recommended checks:

```bash
./manage.sh status /path/to/your/real-project
./manage.sh verify /path/to/your/real-project
./manage.sh release-check /path/to/your/real-project
```

Successful verification means the target project now contains:

- `.claude/commands/trellis-sp/brainstorm.md`
- `.claude/commands/trellis-sp/specify.md`
- `.claude/commands/trellis-sp/clarify.md`
- `.claude/commands/trellis-sp/plan.md`
- `.claude/commands/trellis-sp/execute.md`
- `.claude/skills/trellis-sp-local/SKILL.md`

### 4. Use the new commands inside the target project

In Claude Code within that project, the added workflow is:

```text
/trellis:start
/trellis-sp:brainstorm
/trellis-sp:specify
(/trellis-sp:clarify if needed)
/trellis-sp:plan
/trellis-sp:execute
/trellis:check
/trellis:finish-work
```

After `/trellis-sp:brainstorm`, the default next step is `/trellis-sp:specify`. Use `/trellis-sp:clarify` only when high-value ambiguities remain; otherwise continue to `/trellis-sp:plan` once the PRD is planning-ready.

This adapter lane does **not** replace native `/trellis:brainstorm`; it is an explicit enhancement path entered through `/trellis-sp:brainstorm`. Once that adapter path is chosen, do not route the user back to native brainstorm.

Current-task rules in this adapter flow:

- `/trellis:start` is still the recommended session entrypoint, but the adapter commands must manage Trellis task state correctly even when they are invoked directly.
- `/trellis-sp:brainstorm` should ensure there is a parent task and set `.trellis/.current-task` to that parent before handing off to `/trellis-sp:specify`.
- `/trellis-sp:brainstorm` should immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase brainstorm` when a parent task is created or when the adapter marker is missing or stale.
- `/trellis-sp:specify` should immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase specify` before finishing so the active parent task remains adapter-identifiable.
- `/trellis-sp:plan` should keep the parent task as the current task while creating or updating child tasks.
- `/trellis-sp:plan` should immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase plan` while planning is active, then run `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase execute` once the parent is ready for execution handoff.
- `/trellis-sp:plan` should immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <child-task-dir> --role child --phase execute` for every child task it creates or refines.
- `/trellis-sp:execute` should switch `.trellis/.current-task` to each child task before running child-local `implement` / `check` / `debug`, then restore the parent task before the final parent-level `check`.
- `/trellis:finish-work` remains the Trellis-native finish and handoff step. In the adapter lane, it should only happen after `/trellis-sp:execute` restores the parent task and the parent-level final `check` has passed cleanly.
- Child tasks are staged execution units only; do not treat any child task as independently ready for `/trellis:finish-work`.
- Before handing off to `/trellis:finish-work`, evaluate whether the workflow surfaced reusable rules, constraints, or debugging lessons that should be promoted via `/trellis:update-spec`.
- After `/trellis:finish-work`, use `/trellis:record-session` when the staged execution produced durable decisions or review findings that should survive into later sessions.

For already-clear requirements, a shorter path is usually enough:

```text
/trellis:start
/trellis-sp:specify
/trellis-sp:plan
/trellis-sp:execute
```

### 5. Operational notes

- Treat the target project's active task `prd.md` as the single source of truth for task-level feature specs.
- `/trellis-sp:brainstorm` uses a Trellis-native flow adapted from Superpowers, keeps all requirements in the Trellis task PRD, and should ensure the parent task is the active current task before `/trellis-sp:specify`.
- `/trellis-sp:brainstorm`, `/trellis-sp:specify`, and `/trellis-sp:plan` are also responsible for keeping `task.json.meta.trellis_sp` fresh through `.claude/scripts/trellis-sp-task-meta.py`, so parent and child tasks stay recognizable across sessions.
- `/trellis-sp:plan` decomposes broad planning-ready work into atomic child tasks when needed, then prepares task-local execution contracts in parent/child `info.md` and task jsonl files instead of creating external Superpowers plan artifacts. Planning keeps the parent task as `.trellis/.current-task`.
- `/trellis-sp:execute` uses local execution discipline adapted from Superpowers, runs those child tasks progressively, and routes real work through Trellis-compatible `research` / `implement` / `check` / `debug` subagents so hook-based progressive disclosure and Ralph Loop can apply again. Child execution should temporarily switch `.trellis/.current-task` to the child task, then restore the parent before the final parent-level `check`.
- `/trellis:start` should inspect `task.json.meta.trellis_sp` during both current-task resume and manual task selection. Managed parent tasks should resume from parent `prd.md` plus any task-local `info.md`; managed child tasks should resume from child `prd.md` plus the parent `prd.md` and parent `info.md`, then finish the active child loop before returning to the parent final `check`.
- The adapter intentionally does **not** hand execution over to the Trellis `dispatch` agent today. This keeps the adapter limited to a lightweight execution bridge instead of coupling it to the full Trellis phase-orchestration pipeline (`task.json.next_action`, finish/create-pr semantics, and deeper dispatch assumptions). The current design preserves Trellis hook/context benefits without forcing adapter users into the complete dispatch lifecycle.
- Do not expect this adapter to create `specs/` or `.specify/` state.
- If install detects drift in adapter-managed files, it refuses to overwrite by default.
- This adapter exists specifically to avoid requiring a Superpowers installation in Trellis projects where hook auto-loading would conflict.

## Example: how atomic child-task planning should look

A good `/trellis-sp:plan` result should not leave a broad task as one opaque implementation pass when staged delivery is clearly needed.

For example, suppose the active Trellis task is:

- parent task: `add atomic workflow to adapter`

A strong planning result would keep that parent task as the umbrella requirement and split execution into reviewable child tasks such as:

1. `update plan command contract`
   - scope: teach `/trellis-sp:plan` to decompose broad work into atomic child tasks
   - likely files: `overlay/.claude/commands/trellis-sp/plan.md`, `overlay/.claude/skills/trellis-sp-local/SKILL.md`
   - verification: child task docs explicitly mention parent/child decomposition and task-local execution contracts

2. `update execute command contract`
   - scope: teach `/trellis-sp:execute` to run child tasks progressively with checkpoints
   - likely files: `overlay/.claude/commands/trellis-sp/execute.md`, `lib/trellis-target.sh`
   - verification: docs explicitly require sequential child execution, `check`/`debug` loops, and parent-level final `check`

3. `update adapter verification and docs`
   - scope: align `verify.sh`, README, and integration docs with the new workflow contract
   - likely files: `verify.sh`, `README.md`, `README_INTEGRATION_CN.md`, `SUPERPOWERS_TRELLIS_INTEGRATION_CN.md`
   - verification: verify passes and explanatory docs describe the same workflow

In that model:

- the parent task keeps the overall PRD and the ordered execution plan in `info.md`
- each child task gets its own narrowed `prd.md`, `info.md`, and jsonl context files
- `/trellis-sp:execute` should work child-by-child instead of treating the parent task as one undifferentiated implementation step
- after each child reaches a clean `check`, the workflow should pause at a review checkpoint before advancing
- once all children are complete, the workflow should run a parent-level final `check`

A practical minimum template is:

### Parent `info.md`
- goal
- ordered child task list
- child-to-file map
- verification strategy
- review checkpoints

### Child `prd.md`
- one atomic goal
- a short requirement list
- 1-2 verifiable acceptance criteria
- likely touched files

### Child execution checklist
- `implement` completes only that child scope
- `check` passes for that child
- `debug` is used if needed before advancing
- checkpoint summary happens before moving to the next child

This is the intended meaning of “Superpowers-style decomposition, Trellis-native execution”.

### 6. Upgrading later

After upgrading Trellis in the real project, re-run:

```bash
./bootstrap.sh /path/to/your/real-project
```

The adapter is designed to be reapplied as an overlay instead of patching Trellis core.

## Unified entrypoint

Use `manage.sh` as the main entrypoint:

```bash
./manage.sh bootstrap /path/to/your/trellis-project
./manage.sh status /path/to/your/trellis-project
./manage.sh doctor /path/to/your/trellis-project
./manage.sh install /path/to/your/trellis-project
./manage.sh restore /path/to/your/trellis-project <snapshot-name>
./manage.sh prune-backups /path/to/your/trellis-project keep-latest 3
./manage.sh export-manifest /path/to/your/trellis-project manifest.json
./manage.sh release-check /path/to/your/trellis-project
```

## Lifecycle scripts

- `bootstrap.sh` — safe first-run or repeat-safe setup entrypoint
- `install.sh` — copy the overlay into a Trellis project
- `uninstall.sh` — remove the adapter files from a Trellis project
- `verify.sh` — verify the installed adapter files and the no-runtime-dependency contract
- `restore.sh` — restore a named backup snapshot back into a Trellis project
- `list-backups.sh` — list available backup snapshots, or inspect one snapshot's files and metadata
- `status.sh` — report adapter install state, verify result, Trellis version, and recent backups
- `prune-backups.sh` — delete a specific snapshot or keep only the newest N snapshots
- `doctor.sh` — diagnose adapter health and recommend the next maintenance action
- `manage.sh` — unified wrapper around the adapter lifecycle scripts
- `self-test.sh` — read-only smoke test for the adapter diagnostics toolchain
- `export-manifest.sh` — export machine-readable adapter state for sharing or debugging
- `release-check.sh` — run a release-oriented validation pass

## Install

```bash
./install.sh /path/to/your/trellis-project
```

By default, install refuses to overwrite adapter-managed files that already exist with different contents.

## Force install

Allow overwriting conflicting files:

```bash
ADAPTER_FORCE=1 ./install.sh /path/to/your/trellis-project
```

When forcing, the installer backs up conflicting files by default under:

```text
.claude/adapter-backups/trellis-superpowers-adapter/<timestamp>/
```

Each new backup snapshot also includes `snapshot.json`, which records why the snapshot was created and which adapter files it contains.

Disable backup only if you explicitly want destructive replacement:

```bash
ADAPTER_FORCE=1 ADAPTER_BACKUP=0 ./install.sh /path/to/your/trellis-project
```

## Verify

```bash
./verify.sh /path/to/your/trellis-project
```

## Uninstall

```bash
./uninstall.sh /path/to/your/trellis-project
```

## Dry run

Preview actions without changing files:

```bash
ADAPTER_DRY_RUN=1 ./install.sh /path/to/your/trellis-project
ADAPTER_DRY_RUN=1 ./verify.sh /path/to/your/trellis-project
ADAPTER_DRY_RUN=1 ./uninstall.sh /path/to/your/trellis-project
ADAPTER_DRY_RUN=1 ./restore.sh /path/to/your/trellis-project <snapshot-name>
ADAPTER_DRY_RUN=1 ./prune-backups.sh /path/to/your/trellis-project keep-latest 3
```

You can combine dry-run with force settings to preview conflict handling.

## Design goals

- No edits to `packages/cli/` Trellis core templates
- No edits to built-in `.claude/commands/trellis/*`
- No default `SessionStart` coupling with Superpowers
- No runtime dependency on external Superpowers skills or plugin installation
- Trellis remains the source of truth for `.trellis/tasks/`, `.trellis/spec/`, and `.trellis/workspace/`
- Task-level feature specs live in the active task `prd.md`, not in a parallel `specs/` or `.specify/` workspace
- Reinstallable after Trellis upgrades by rerunning `install.sh`
- Safe by default when adapter-managed files have drifted
- Recoverable from backup snapshots created during forced replacement

## Metadata

Runtime task identity for this adapter lives in `task.json.meta.trellis_sp`.

Expected fields:

- `managed` — whether the task is adapter-managed
- `role` — `parent` or `child`
- `workflow_version` — current metadata schema version
- `last_phase` — latest adapter phase such as `brainstorm`, `specify`, `plan`, or `execute`

The adapter installs `.claude/scripts/trellis-sp-task-meta.py` to write and refresh these fields without changing Trellis core scripts.

See `adapter.json` for the adapter version, compatibility data, installed paths, snapshot metadata filename, conflict policy, lifecycle scripts, and the explicit no-runtime-skill dependency contract.

## Changelog

See `CHANGELOG.md` for the version history of the adapter package.
