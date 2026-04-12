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
- Keep task-level feature specs in the active task `prd.md` instead of creating `specs/` or `.specify/` state.
- Apply Superpowers-inspired workflow behavior locally inside adapter commands rather than through runtime skill dependencies.
- Use Superpowers as a method source, but route real implementation/review work through Trellis-compatible subagents when progressive disclosure matters.
- Formal adapter research must use Trellis research-agent semantics with explicit `subagent_type: "research"` rather than generic Explore-style routing.
- Reapply this adapter through lifecycle scripts instead of patching Trellis core after upgrades.

## Workflow interoperability

In projects using this adapter, `/trellis-sp:brainstorm` is the adapter's valid implementation of the brainstorm phase that `/trellis:start` normally expects for complex tasks.

Once the adapter path is chosen:
- do not redirect the user back to `/trellis:brainstorm`
- after `/trellis-sp:brainstorm`, the default next step is `/trellis-sp:specify`
- use `/trellis-sp:clarify` only if high-value ambiguities remain
- use `/trellis-sp:plan` when the task is already planning-ready or after `/trellis-sp:specify` or `/trellis-sp:clarify` has made it planning-ready
- treat `/trellis-sp:plan` as the step that creates a Trellis-native atomic child-task workflow when staged delivery is needed
- continue to `/trellis-sp:execute` after planning is complete
- treat `/trellis-sp:execute` as the step that runs those atomic child tasks progressively through Trellis-compatible subagents and review checkpoints
- treat formal research in this flow as Trellis research, explicitly routed with `subagent_type: "research"`

## Installed commands

- `/trellis-sp:brainstorm` → local brainstorming discipline adapted from Trellis + Superpowers
- `/trellis-sp:specify` → Trellis-native task PRD spec authoring
- `/trellis-sp:clarify` → Trellis-native task PRD clarification
- `/trellis-sp:plan` → local planning discipline adapted from Superpowers + Trellis-native atomic child-task decomposition and parent/child task-local execution contracts
- `/trellis-sp:execute` → local execution discipline adapted from Superpowers + progressive child-task execution through Trellis-compatible subagents and review checkpoints

## Lifecycle

- Install with `trellis-superpowers-adapter/install.sh`
- Verify with `trellis-superpowers-adapter/verify.sh`
- Remove with `trellis-superpowers-adapter/uninstall.sh`

## Reinstall after Trellis upgrade

Re-run the adapter install script to copy this overlay back into the upgraded Trellis project. The adapter is designed to live outside Trellis core so it can be reattached quickly after upgrades.
