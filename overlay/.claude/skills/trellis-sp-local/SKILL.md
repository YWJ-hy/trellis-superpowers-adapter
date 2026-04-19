---
name: trellis-sp-local
description: |
  Pluggable Trellis adapter that vendors Superpowers-inspired workflow behavior
  locally alongside Trellis-native task-spec commands, without modifying Trellis
  core templates, hooks, or built-in commands.
---

# Trellis-Superpowers Local Adapter

## Purpose

This adapter keeps Trellis as the repository workflow system and exposes Superpowers-inspired workflow behavior through local `/trellis-sp:*` commands.

Superpowers installation is not required at runtime. The adapter vendors and adapts the relevant workflow guidance locally so Trellis and Superpowers do not conflict through hook auto-loading.

## Design rules

- Do not modify Trellis core templates under `packages/cli/`.
- Do not modify built-in Trellis commands under `.claude/commands/trellis/`.
- Do not wire Superpowers into Trellis `SessionStart` by default.
- Keep repo artifacts in Trellis locations such as `.trellis/tasks/`, `.trellis/spec/`, and `.trellis/workspace/`.
- Keep task-level reviewed feature specs in the active task `prd.md` instead of creating `specs/` or `.specify/` state.
- Introduce parent `normalize.md` as the task-local, source-faithful requirement normalization ledger before formal specification.
- Introduce parent `memorandum.md` as the task-local memo for deferred, excluded, conflicting, pending, blocked, resolved, or promoted items that should not silently vanish.
- Preserve requirement-to-proof traceability task-locally through parent `prd.md`, parent `trace.md`, parent/child `info.md`, and task-local verification checkpoints.
- Treat task-local `implement.jsonl`, `check.jsonl`, and `debug.jsonl` as Trellis-native preload context only: relevant `.trellis/spec/...` files, shared guides/docs, and only minimal reusable code-pattern references when truly needed.
- Do not use task-local jsonl files to preload likely touched business code files; record runtime code-reading guidance in task `info.md` instead.
- When creating Trellis tasks through `task.py create --slug`, pass only a bare semantic slug; do not include a date prefix because `task.py create` already prepends `MM-DD-` to the task directory name.
- Apply Superpowers-inspired workflow behavior locally inside adapter commands rather than through runtime skill dependencies.
- Use Superpowers as a method source, but route real implementation/review work through Trellis-compatible subagents when progressive disclosure matters.
- Formal adapter research must use Trellis research-agent semantics with explicit `subagent_type: "research"` rather than generic Explore-style routing.
- Reapply this adapter through lifecycle scripts instead of patching Trellis core after upgrades.

## Workflow interoperability

In projects using this adapter, `/trellis-sp:brainstorm` is the adapter's valid implementation of the brainstorm phase that `/trellis:start` normally expects for complex tasks.

Once the adapter path is chosen:
- do not redirect the user back to `/trellis:brainstorm`
- after `/trellis-sp:brainstorm`, the default next step is `/trellis-sp:specify`
- treat `/trellis-sp:brainstorm` as including a mandatory normalization and memorandum substage that creates or refreshes parent `normalize.md` and `memorandum.md` before formal specification
- use `/trellis-sp:clarify` only if high-value ambiguities remain
- use `/trellis-sp:plan` when the task is already planning-ready or after `/trellis-sp:specify` or `/trellis-sp:clarify` has made it planning-ready, and only when the written `Spec Review Gate` allows planning to proceed
- treat `/trellis-sp:plan` as the step that creates a Trellis-native atomic child-task workflow when staged delivery is needed, with runtime code-reading guidance written into parent/child `info.md` and requirement ownership recorded in parent `trace.md`
- continue to `/trellis-sp:execute` after planning is complete
- treat `/trellis-sp:execute` as the step that runs those atomic child tasks progressively through Trellis-compatible subagents and review checkpoints, reading real business code at runtime from child-local guidance (`Relevant Parent Context Slice`, `Read First`, and likely touched-file guidance) instead of relying on jsonl preloading or full parent-doc reads by default
- require spec-compliance review against inherited requirement IDs before broader code-quality review during execution, and use `trace.md` to close proof at child and parent checkpoints
- when post-execution human verification finds implementation deviation or changed requirements, use `/trellis-sp:replan` to update the parent task and produce a delta handling plan before returning to `/trellis-sp:execute`
- treat child tasks with `task.json.status` of `completed` or `done` as finished history; corrective execution should skip them by default and use new follow-up child tasks for reviewable fixes
- treat `last_phase=replan` as a truthful replan-complete state; if a session ends before `/trellis-sp:execute` starts, the next session should resume corrective execution from parent metadata rather than collapsing that state into a generic execute-ready parent
- treat formal research in this flow as Trellis research, explicitly routed with `subagent_type: "research"`
- treat `/trellis:finish-work` as a Trellis-native parent-level handoff that happens only after `/trellis-sp:execute` restores the parent task and the parent-level final `check` passes cleanly
- do not treat child tasks as independently ready for `/trellis:finish-work`
- before that handoff, evaluate whether the adapter lane discovered reusable project-wide rules that should be promoted via `/trellis:update-spec`
- after finish-work, use `/trellis:record-session` when the workflow produced durable staged-execution or review knowledge worth preserving across sessions

## Installed commands

- `/trellis-sp:brainstorm` → local brainstorming discipline adapted from Trellis + Superpowers with parent `normalize.md` and `memorandum.md` prepared before formal specification
- `/trellis-sp:specify` → Trellis-native task PRD spec authoring with normalized-input formalization, memo filtering, preserved critical details, and a written `Spec Review Gate`
- `/trellis-sp:clarify` → Trellis-native task PRD clarification that keeps requirement IDs stable and refreshes stale written review state when needed
- `/trellis-sp:plan` → local planning discipline adapted from Superpowers + Trellis-native atomic child-task decomposition, parent `trace.md`, and parent/child task-local execution contracts
- `/trellis-sp:execute` → local execution discipline adapted from Superpowers + progressive child-task execution through Trellis-compatible subagents, spec-compliance review, and review checkpoints
- `/trellis-sp:replan` → post-verification delta planning for adapter-managed parent tasks after human validation finds implementation deviation or changed requirements, preserving trace history

## Lifecycle

- Install with `trellis-superpowers-adapter/install.sh`
- Verify with `trellis-superpowers-adapter/verify.sh`
- Remove with `trellis-superpowers-adapter/uninstall.sh`

## Reinstall after Trellis upgrade

Re-run the adapter install script to copy this overlay back into the upgraded Trellis project. The adapter is designed to live outside Trellis core so it can be reattached quickly after upgrades.
