---
name: brainstorm
description: Run a Trellis-native brainstorming flow adapted from Superpowers discipline
---

# Trellis-Superpowers Brainstorm

Use a Trellis-native brainstorming process adapted from Superpowers, but keep Trellis as the source of truth.

## Non-negotiable rules

- Treat `.trellis/` as the only repo-level source of truth for tasks, specs, and workspace memory.
- Keep evolving requirements in the active Trellis task `prd.md`.
- When this adapter path is chosen, keep the active parent task identifiable in `task.json` under `meta.trellis_sp`; ensure `managed=true`, `role="parent"`, `workflow_version=1`, and keep `last_phase` aligned with the latest adapter step.
- Do not modify `.claude/settings.json`, Trellis hooks, or built-in `trellis/*` commands as part of this command.
- Do not create a parallel planning, spec, or memory system outside `.trellis/tasks/`.
- Do not move into planning, execution, or code changes until the design direction is clear and the user has confirmed the requirements summary.
- When formal research is needed to compare technical options against repo patterns, specs, or likely touched files, do not use generic Explore-style routing as the authoritative step. Explicitly use the Trellis research agent with `subagent_type: "research"`.

## Goal

Turn an idea or ambiguous task into a Trellis-native, PRD-backed set of confirmed requirements that is ready for the next workflow step.

## Workflow

1. Resolve task context first:
   - confirm there is an active Trellis task
   - if no active task exists, create a Trellis task for this work and set it as the current task before deep brainstorming continues
   - when you create the task, immediately run `python3 ./.trellis/scripts/task.py start <task-dir>` so `.trellis/.current-task` points to the parent task
   - ensure the active or newly created parent task remains marked in `task.json` under `meta.trellis_sp` with `managed=true`, `role="parent"`, `workflow_version=1`, and `last_phase="brainstorm"`
   - immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase brainstorm` whenever you create the task or detect that the marker is missing or stale
   - open or create the active task `prd.md`
2. Inspect current context before asking:
   - review relevant repo files, docs, and active task state
   - update `prd.md` with confirmed facts and constraints you can derive without asking the user
3. Clarify one thing at a time:
   - ask one question per message
   - prefer multiple-choice questions when possible
   - if a technical choice depends on patterns, specs, or likely touched files, first run formal Trellis research with explicit `subagent_type: "research"`, then present 2-3 feasible approaches with trade-offs
4. Expand briefly before converging:
   - consider likely future evolution
   - related scenarios or parity expectations
   - failure and edge cases that matter for MVP scope
5. Keep the Trellis task authoritative:
   - after each meaningful answer, update `prd.md`
   - move resolved questions into concrete requirements, assumptions, success criteria, or out-of-scope notes
6. Confirm the design direction before handoff:
   - summarize the goal, included scope, excluded scope, and key decisions
   - do not proceed until the user has confirmed the requirements summary
7. Adapter phase handoff:
   - completion of `/trellis-sp:brainstorm` satisfies the brainstorm phase for the adapter path after `/trellis:start`
   - do not redirect the user back to `/trellis:brainstorm`
   - after brainstorm, the default next Trellis-native adapter step is `/trellis-sp:specify` so the active task `prd.md` is structured into a planning-ready spec
   - recommend `/trellis-sp:clarify` only when high-value ambiguities still remain after the brainstorm summary is confirmed
   - recommend `/trellis-sp:plan` only when the task is already planning-ready or after `/trellis-sp:specify` or `/trellis-sp:clarify` has made it planning-ready
   - when the task is broad enough to need staged delivery, `/trellis-sp:plan` should decompose the active task into atomic child tasks for later progressive execution

## Brainstorming discipline to preserve

- Task-first and PRD-first
- Action before asking
- One question per message
- Prefer 2-3 concrete options with trade-offs
- Research before asking the user to invent technical options
- Diverge briefly, then converge to an explicit MVP
