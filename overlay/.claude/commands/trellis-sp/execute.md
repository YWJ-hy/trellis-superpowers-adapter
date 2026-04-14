---
name: execute
description: Apply local execution discipline adapted from Superpowers through Trellis subagents
---

# Trellis-Superpowers Execute

Use a local execution discipline adapted from Superpowers, but keep Trellis as the source of truth for task state, context injection, and verification.

## Non-negotiable rules

- Only use this command when an active Trellis task already exists and `.trellis/.current-task` points to it.
- Treat `.trellis/tasks/` as the system of record for requirements, execution context, and completion state.
- Require the active task to contain `prd.md`, `implement.jsonl`, and `check.jsonl` before execution begins. If any of them are missing, stop and tell the user to run `/trellis-sp:plan` first.
- `debug.jsonl` is optional at start and may be created or extended later if debugging becomes necessary.
- Do not modify `.claude/settings.json`, Trellis hooks, or built-in `trellis/*` commands as part of this command.
- Do not let this command introduce a parallel execution workflow, external plan artifact, or default worktree requirement unless the user explicitly asks for it.
- Do not treat freeform inline implementation in the main session as the primary path. Real code work must run through Trellis-compatible subagents.
- If a context gap remains before implementation, use the Trellis research agent explicitly with `subagent_type: "research"`. Do not treat generic Explore-style inspection as a substitute for task-context-building research.

## Goal

Preserve disciplined staged execution while routing all substantive work through Trellis-supported subagent types so hook-based progressive disclosure and Ralph Loop apply again.

## Workflow

1. Validate execution readiness:
   - confirm there is an active task
   - confirm `.trellis/.current-task` resolves correctly
   - confirm the active parent task has `prd.md`, `implement.jsonl`, and `check.jsonl`
   - review parent `info.md` or other task-local plan context if present
   - if the workflow was planned as atomic execution, confirm the parent task has ordered child tasks and that each atomic child task has `prd.md`, `implement.jsonl`, and `check.jsonl`
   - if task context is incomplete, stale, or has critical gaps, stop and send the user back to `/trellis-sp:plan`
2. Announce that you are using a local execution discipline adapted from Superpowers, but Trellis subagents remain the execution engine.
3. Use this execution discipline:
   - review the task-local plan critically before each stage
   - execute ordered atomic child tasks progressively rather than treating the whole task as one opaque implementation pass
   - stop on blockers instead of guessing
   - require review checkpoints before advancing
4. Route real work only through Trellis-compatible subagent types:
   - `research` only as a gap-repair step if a context gap remains before implementation; when used, explicitly route it with `subagent_type: "research"`
   - `implement` for code changes
   - `check` for review and verification
   - `debug` if issues found during check or verification require focused fixes
5. Keep execution task-local:
   - parent requirements remain in the active task `prd.md`
   - parent sequencing and child-task plan remain in parent `info.md` if present
   - each atomic child task carries its own narrowed `prd.md`, `info.md`, and task-local jsonl files
   - do not create or depend on `docs/superpowers/plans/...`
6. Atomic child-task execution loop:
   - execute child tasks in their planned order
   - before executing each child task, run `python3 ./.trellis/scripts/task.py start <child-task-dir>` so `.trellis/.current-task` points to that child
   - for each atomic child task, use its local context and run `implement`
   - after each child implementation pass, run Trellis `check`
   - if `check` identifies issues, use `debug` or return to `implement` as appropriate for that same child task
   - do not advance to the next child while verification issues remain in the current one
7. Review checkpoints are mandatory:
   - after each atomic child task reaches a clean `check` result, pause long enough to summarize what changed, what was verified, and whether any new plan gaps were revealed
   - if execution uncovers a missing requirement or a decomposition mistake, update the parent or child Trellis task artifacts before continuing
8. Final verification must go through Trellis `check`.
   - This is required so Trellis `SubagentStop(check)` behavior, including Ralph Loop, can apply to this route again.
   - After all atomic child tasks complete, restore `.trellis/.current-task` to the parent task and then run a parent-level final `check` for cross-child integration and overall requirements coverage.
   - If a finish-like final pass is needed, use Trellis `check` semantics rather than introducing an external finishing flow.
9. Finish bridge rules:
   - do not treat any child task as individually ready for `/trellis:finish-work`
   - only the parent task may hand off to `/trellis:finish-work`
   - that handoff happens only after the parent-level final `check` passes cleanly
10. End by reporting:
   - which atomic child tasks completed
   - whether any blockers remain
   - whether the parent-level final `check` passed
   - whether the workflow is ready to hand off to `/trellis:finish-work`
   - the next Trellis-native step, usually `/trellis:finish-work` or task follow-up work

## Recommended execution checklist

For each atomic child task, prefer a checklist like this before moving on:

- [ ] child task `prd.md` is still accurate
- [ ] child task `implement.jsonl` and `check.jsonl` still point to the right context
- [ ] `implement` completed the intended atomic scope only
- [ ] `check` passed, or `debug` was used and `check` passed afterward
- [ ] a short checkpoint summary was recorded before advancing to the next child

Before declaring the whole workflow done:

- [ ] every ordered child task completed
- [ ] no child task is carrying unresolved verification issues
- [ ] parent-level final `check` passed

## Supported execution engine

The only supported execution subagent types for this command are:

- `research`
- `implement`
- `check`
- `debug`

Do not invent additional subagent types for the execution path.
