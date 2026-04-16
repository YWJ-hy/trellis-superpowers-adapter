---
name: plan
description: Apply local planning discipline adapted from Superpowers to a Trellis task
---

# Trellis-Superpowers Plan

Use a local planning discipline adapted from Superpowers, but keep Trellis task artifacts as the system of record.

## Non-negotiable rules

- Treat the active Trellis task as the source of truth for requirements and implementation context.
- Keep the active parent task identifiable in `task.json` under `meta.trellis_sp`; ensure `managed=true`, `role="parent"`, `workflow_version=2`, and keep `last_phase` aligned with the latest adapter step.
- Treat the active task `prd.md` as the requirements contract, including any structure added by `/trellis-sp:specify` or `/trellis-sp:clarify`.
- Formal research in this command must use the Trellis research agent with explicit `subagent_type: "research"`.
- Write the task-level implementation contract into the active task, not into `docs/superpowers/plans/...` or any other external planning workspace.
- Use task-local artifacts for planning outputs:
  - `prd.md` for requirements
  - `info.md` for implementation brief / plan summary and runtime code-reading guidance
  - `implement.jsonl`, `check.jsonl`, and `debug.jsonl` for Trellis-native progressive-disclosure context
- Keep task-local jsonl files limited to Trellis-native preloaded context: relevant `.trellis/spec/...` files, shared guides/docs, and only minimal reusable code-pattern references when truly needed.
- Do not use task-local jsonl files to preload likely touched business code files; record those runtime code targets in `info.md` instead.
- Do not modify `.claude/settings.json`, Trellis hooks, or built-in `trellis/*` commands as part of this command.
- If requirements are still unclear or no Trellis task exists, stop and resolve that first.

## Goal

Apply a local planning discipline adapted from Superpowers while following the Trellis research-first-before-implementation path: requirements first, then formal research/context preparation, then a Trellis-native execution contract.

## Workflow

1. Validate prerequisites:
   - confirm there is an active Trellis task
   - confirm the active task `prd.md` exists and is planning-ready
   - treat the active task as the parent or umbrella task unless the task is already atomic
2. Announce that you are using a local planning discipline adapted from Superpowers, but Trellis task artifacts remain authoritative.
3. Research happens after requirements are clear and before implementation:
   - the purpose of formal research is to identify relevant `.trellis/spec/...` files, existing code patterns to follow, and likely touched files
   - if current task context is incomplete, stale, or insufficient for implementation, explicitly call the Trellis research agent with `subagent_type: "research"`
4. Handle research with a Trellis-aligned conditional policy:
   - If task-local context files are missing, invalid, or clearly insufficient, first prepare context using formal Trellis research:
     - use `subagent_type: "research"`
     - identify relevant specs, patterns, and likely touched files
     - if the parent task is missing `implement.jsonl`, `check.jsonl`, or `debug.jsonl`, initialize them first with `python3 ./.trellis/scripts/task.py init-context <parent-task-dir> <dev_type>`
     - add only research-selected Trellis-native preload context to task jsonl files with `python3 ./.trellis/scripts/task.py add-context <parent-task-dir> <implement|check|debug> <path> <reason>`
     - treat likely touched business code files as runtime reading targets and record them in `info.md`, not in task jsonl files
     - validate the parent task context before proceeding
   - If existing `implement.jsonl`, `check.jsonl`, and related task-local context are already valid and sufficient, you may skip fresh research and reuse the existing context.
5. Plan with these priorities:
   - decomposition quality
   - explicit file-path thinking and likely touched files
   - implementation sequencing
   - verification-first design
   - quick self-review against `prd.md` before handoff
6. Decompose planning-ready work into atomic Trellis child tasks when the active task is too broad for a single reviewable implementation pass:
   - use normal Trellis child tasks rather than inventing a new storage format
   - create or define child tasks with the existing parent/child task mechanism under `.trellis/tasks/`
   - keep the parent task as `.trellis/.current-task` throughout planning, even while creating or editing child tasks
   - do not leave a newly created child task as the current task at the end of planning
   - ensure the parent task still has `meta.trellis_sp.managed=true`, `role="parent"`, `workflow_version=2`, and keep `last_phase="plan"` while planning is active
   - before execution handoff, ensure the parent task has its own `implement.jsonl`, `check.jsonl`, and `debug.jsonl`; initialize them with `python3 ./.trellis/scripts/task.py init-context <parent-task-dir> <dev_type>` if they are missing, then refine them with research-driven `add-context` entries for Trellis-native parent-level preload context and final integration checks
   - immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase plan` while planning is active, and once the parent is ready to hand off to execution record `resume_source=plan` with `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase plan --resume-source plan`
   - whenever you create or refine an atomic child task for this adapter flow, mark that child task in `task.json` under `meta.trellis_sp` with `managed=true`, `role="child"`, `workflow_version=2`, and `last_phase="execute"`
   - for every child task you create or refine in this adapter flow, initialize missing child jsonl files with `python3 ./.trellis/scripts/task.py init-context <child-task-dir> <dev_type>` before narrowing them to child-local context
   - immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <child-task-dir> --role child --phase execute --clear-resume` for every child task you create or refine in this adapter flow
   - prefer one child task per independent verification unit, file cluster, or review checkpoint
   - avoid splitting trivial work that belongs in the same implementation and verification pass
7. For each atomic child task, prepare a Trellis-native execution contract:
   - child `prd.md` should narrow scope to one atomic outcome
   - child `info.md` should summarize approach, sequencing, `Read First`, likely touched files, verification expectations, and blockers
   - child `implement.jsonl`, `check.jsonl`, and `debug.jsonl` should contain only the Trellis-native preload context needed for that child, not likely touched business code files
   - reuse parent requirements and shared specs where relevant, but keep the child focused and reviewable
8. Persist planning output into Trellis task artifacts only:
   - update or create parent `info.md` as the implementation brief / execution contract for the whole workflow
   - record the ordered child-task plan in the parent task, including atomic child tasks, sequencing, and review checkpoints
   - refresh parent and child task-local context files as needed:
     - `implement.jsonl`
     - `check.jsonl`
     - `debug.jsonl`
   - before ending this command, validate that the parent task now satisfies `/trellis-sp:execute` prerequisites for task-local artifacts, especially `prd.md`, `implement.jsonl`, and `check.jsonl`
9. Keep the plan task-local and execution-oriented:
   - parent `info.md` should summarize the overall approach, ordered atomic child tasks, likely touched files, verification strategy, stop conditions, and any shared runtime code-reading guidance
   - child task artifacts should make each atomic step executable by Trellis subagents without relying on external planning files
   - jsonl files should point to the Trellis specs and minimal reusable code-pattern references needed later by `implement`, `check`, and `debug`
10. Do not introduce assumptions from raw Superpowers that conflict with Trellis:
   - no default external plan files
   - no required worktree setup unless the user explicitly asks
   - no automatic commit-oriented plan steps as the task contract
11. Parent-level finish bridge rules:
   - child tasks are execution units, not finish units
   - `/trellis:finish-work` belongs only after `/trellis-sp:execute` restores the parent task and the parent-level final `check` passes cleanly
   - do not describe any child task as ready for `/trellis:finish-work` on its own
12. End by stating that `/trellis-sp:execute` should run the atomic child-task workflow progressively through Trellis-compatible subagents and review checkpoints, then hand off to `/trellis:finish-work` only after the parent-level final `check` is clean.

## Planning outputs

The intended task-local outputs of this command are:

- active parent task `prd.md`
- active parent task `info.md`
- active parent task `implement.jsonl`
- active parent task `check.jsonl`
- active parent task `debug.jsonl`
- ordered atomic child tasks under `.trellis/tasks/` when decomposition is needed
- each child task's `prd.md`
- each child task's `info.md`
- each child task's `implement.jsonl`
- each child task's `check.jsonl`
- each child task's `debug.jsonl`

## Recommended artifact templates

When `/trellis-sp:plan` decides that staged delivery is needed, prefer artifact shapes like these.

### Parent task `info.md`

Use the parent task to capture the whole workflow:

```markdown
# Execution Plan

## Goal
<feature-level outcome>

## Ordered atomic child tasks
1. <child task 1>
2. <child task 2>
3. <child task 3>

## Child task map
- <child task 1>: <scope and likely touched files>
- <child task 2>: <scope and likely touched files>
- <child task 3>: <scope and likely touched files>

## Shared runtime reading targets
- <shared code area 1>
- <shared code area 2>

## Verification strategy
- [ ] each child task reaches a clean `check`
- [ ] parent-level final `check` passes

## Review checkpoints
- checkpoint after child 1
- checkpoint after child 2
- final checkpoint after parent-level `check`
```

### Child task `prd.md`

Keep each child task narrow and reviewable:

```markdown
# <Child Task Title>

## Goal
<one atomic outcome>

## Requirements
- <requirement 1>
- <requirement 2>

## Acceptance Criteria
- [ ] <specific verifiable result>
- [ ] Trellis `check` passes for this child task

## Likely Touched Files
- <path 1>
- <path 2>
```

### Child task `info.md`

Use the child task to provide runtime code-reading guidance instead of preloading business code via jsonl:

```markdown
# Child Execution Brief

## Goal
<one atomic outcome>

## Read First
- <entry file 1>
- <entry file 2>

## Likely Touched Files
- <path 1>
- <path 2>

## Suggested Implementation Sequence
1. <step 1>
2. <step 2>
3. <step 3>

## Verification Targets
- <verification target 1>
- <verification target 2>

## Blockers / Assumptions
- <blocker or assumption>
```

### Parent task context minimum

Before `/trellis-sp:plan` hands off to `/trellis-sp:execute`, the parent task must have:
- `implement.jsonl`
- `check.jsonl`
- `debug.jsonl`

At minimum, these should point to:
- the parent task `prd.md`
- the parent task `info.md`
- relevant `.trellis/spec/...` files
- shared guides/docs needed across child tasks
- only minimal reusable code-pattern examples when truly needed
- any parent-level integration or cross-child verification references needed for the final `check`

Do not use parent jsonl files to preload likely touched business code files; keep those runtime targets in parent `info.md`.

### Child task context minimum

Each child task should usually have:
- `implement.jsonl`
- `check.jsonl`
- `debug.jsonl`

At minimum, these should point to:
- the child task `prd.md`
- the parent task `prd.md`
- the parent task `info.md`
- relevant `.trellis/spec/...` files
- shared guides/docs the child task needs
- only minimal reusable code-pattern examples when truly needed

Do not use child jsonl files to preload likely touched business code files; put `Read First`, `Likely Touched Files`, sequencing, and verification targets in child `info.md`.

## Important bridge rule

Research is Trellis-standard in documented planning flows. In this adapter, fresh formal research may be skipped only when the active task already has a valid and sufficient execution context from prior Trellis-style research and context preparation.
