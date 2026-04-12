---
name: plan
description: Apply local planning discipline adapted from Superpowers to a Trellis task
---

# Trellis-Superpowers Plan

Use a local planning discipline adapted from Superpowers, but keep Trellis task artifacts as the system of record.

## Non-negotiable rules

- Treat the active Trellis task as the source of truth for requirements and implementation context.
- Treat the active task `prd.md` as the requirements contract, including any structure added by `/trellis-sp:specify` or `/trellis-sp:clarify`.
- Formal research in this command must use the Trellis research agent with explicit `subagent_type: "research"`.
- Write the task-level implementation contract into the active task, not into `docs/superpowers/plans/...` or any other external planning workspace.
- Use task-local artifacts for planning outputs:
  - `prd.md` for requirements
  - `info.md` for implementation brief / plan summary
  - `implement.jsonl`, `check.jsonl`, and `debug.jsonl` for progressive-disclosure context
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
     - add those paths to task-local jsonl files
     - validate the task context before proceeding
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
   - prefer one child task per independent verification unit, file cluster, or review checkpoint
   - avoid splitting trivial work that belongs in the same implementation and verification pass
7. For each atomic child task, prepare a Trellis-native execution contract:
   - child `prd.md` should narrow scope to one atomic outcome
   - child `info.md` should summarize approach, sequencing, likely touched files, verification expectations, and blockers
   - child `implement.jsonl`, `check.jsonl`, and `debug.jsonl` should contain only the context needed for that child
   - reuse parent requirements and shared specs where relevant, but keep the child focused and reviewable
8. Persist planning output into Trellis task artifacts only:
   - update or create parent `info.md` as the implementation brief / execution contract for the whole workflow
   - record the ordered child-task plan in the parent task, including atomic child tasks, sequencing, and review checkpoints
   - refresh parent and child task-local context files as needed:
     - `implement.jsonl`
     - `check.jsonl`
     - `debug.jsonl`
9. Keep the plan task-local and execution-oriented:
   - parent `info.md` should summarize the overall approach, ordered atomic child tasks, likely touched files, verification strategy, and stop conditions
   - child task artifacts should make each atomic step executable by Trellis subagents without relying on external planning files
   - jsonl files should point to the Trellis specs and code patterns needed later by `implement`, `check`, and `debug`
10. Do not introduce assumptions from raw Superpowers that conflict with Trellis:
   - no default external plan files
   - no required worktree setup unless the user explicitly asks
   - no automatic commit-oriented plan steps as the task contract
11. End by stating that `/trellis-sp:execute` should run the atomic child-task workflow progressively through Trellis-compatible subagents and review checkpoints.

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
- any code-pattern examples the child task needs

## Important bridge rule

Research is Trellis-standard in documented planning flows. In this adapter, fresh formal research may be skipped only when the active task already has a valid and sufficient execution context from prior Trellis-style research and context preparation.
