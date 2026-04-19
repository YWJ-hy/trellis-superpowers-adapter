---
name: brainstorm
description: Run a Trellis-native brainstorming flow adapted from Superpowers discipline
---

# Trellis-Superpowers Brainstorm

Use a Trellis-native brainstorming process adapted from Superpowers, but keep Trellis as the source of truth.

## Non-negotiable rules

- Treat `.trellis/` as the only repo-level source of truth for tasks, specs, and workspace memory.
- Keep the active Trellis task as the task-local source of truth for requirements work.
- Use parent task `normalize.md` as the source-faithful requirement normalization ledger before formalizing the reviewed PRD.
- Use parent task `memorandum.md` to record deferred, excluded, conflicting, pending, or externally blocked items that are not yet part of the committed implementation contract.
- Keep evolving high-level requirements and handoff status in the active Trellis task `prd.md`.
- When this adapter path is chosen, keep the active parent task identifiable in `task.json` under `meta.trellis_sp`; ensure `managed=true`, `role="parent"`, `workflow_version=2`, and keep `last_phase` aligned with the latest adapter step.
- Do not modify `.claude/settings.json`, Trellis hooks, or built-in `trellis/*` commands as part of this command.
- Do not create a parallel planning, spec, or memory system outside `.trellis/tasks/`.
- Do not move into planning, execution, or code changes until the design direction is clear and the user has confirmed the requirements summary.
- When formal research is needed to compare technical options against repo patterns, specs, or likely touched files, do not use generic Explore-style routing as the authoritative step. Explicitly use the Trellis research agent with `subagent_type: "research"`.

## Goal

Turn an idea or ambiguous task into a Trellis-native, normalization-backed set of confirmed requirements that is ready for formal specification in the next workflow step.

## Normalization-first contract

Before this workflow tries to formalize a planning-ready PRD, it must first produce or refresh a task-local `normalize.md` that parses the source material in a source-faithful way.

`normalize.md` is not a summary and not an implementation plan. It is a fine-grained requirement normalization ledger that:
- preserves implementation-relevant facts without collapsing them into high-level prose
- keeps named concepts close to their source wording
- uses broad theme headings while allowing AI-selected subtopics and formats underneath
- records source-grounded facts and source coverage before formal specification begins

`memorandum.md` is a companion working memo, not a second requirement ledger. It records things that came up during normalization or collaboration but should not automatically enter the current committed PRD, such as:
- source-vs-code or source-vs-interface conflicts
- user-deferred work
- explicitly excluded-for-now items
- pending clarifications
- blocked-by-external dependencies
- items later promoted into the committed contract

Recommended top-level themes for `normalize.md` are:
- `## Source Material`
- `## Terminology`
- `## Functional Areas / Modules`
- `## Data, Fields, and Structures`
- `## UI / Interaction Details`
- `## Business Rules and Validations`
- `## State, Flow, and Lifecycle`
- `## Integrations and APIs`
- `## Permissions and Roles`
- `## Edge Cases and Failure Handling`
- `## Non-Functional Constraints`
- `## Source Coverage Index`

Recommended top-level sections for `memorandum.md` are:
- `## Purpose`
- `## Open Conflicts`
- `## Deferred by User`
- `## Explicitly Out for This Round`
- `## Pending Clarifications`
- `## Collaboration Dependencies`
- `## Resolved / Promoted`

Under those broad themes, choose the most natural structure for the source material:
- tables for field groups or endpoint contracts
- rule lists for validations or linkage logic
- ordered lists for flows or lifecycle steps
- short bullets for constraints or assumptions

Minimal invariants for `normalize.md`:
- every material normalized fact gets a stable `N-###` identifier
- every material normalized fact includes a source anchor
- explicit source commitments stay explicit rather than being summarized away
- named frontend UI controls/components and named backend contracts/constraints keep their original semantics
- `## Source Coverage Index` proves the important source sections were parsed and placed somewhere

Minimal invariants for `memorandum.md`:
- every memo item gets a stable `M-###` identifier
- every memo item includes a source or trigger reference
- every memo item has a current status such as `deferred`, `excluded-for-now`, `pending-confirmation`, `blocked-by-external`, `resolved`, or `promoted-to-prd`
- memo items do not silently become committed scope without being re-confirmed and promoted through normalization/specification

## Workflow

1. Resolve task context first:
   - confirm there is an active Trellis task
   - if no active task exists, create a Trellis task for this work and set it as the current task before deep brainstorming continues
   - if you pass `--slug` to `python3 ./.trellis/scripts/task.py create`, pass only a bare semantic slug such as `insurance-rule-management`; do not include a date prefix like `04-15-` because `task.py create` already prepends `MM-DD-` to the directory name
   - when you create the task, immediately run `python3 ./.trellis/scripts/task.py start <task-dir>` so `.trellis/.current-task` points to the parent task
   - ensure the active or newly created parent task remains marked in `task.json` under `meta.trellis_sp` with `managed=true`, `role="parent"`, `workflow_version=2`, and `last_phase="brainstorm"`
   - immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase brainstorm` whenever you create the task or detect that the marker is missing or stale
   - open or create the active task `normalize.md`
   - open or create the active task `memorandum.md`
   - open or create the active task `prd.md`
2. Inspect current context before asking:
   - review relevant repo files, docs, and active task state
   - update `normalize.md` with confirmed facts and constraints you can derive without asking the user
   - update `memorandum.md` with any repo-visible or interface-visible conflicts that cannot yet be formalized into committed scope
   - keep `prd.md` lightweight at this stage: goal, current scope direction, and handoff status are enough; do not force a planning-ready formal spec during brainstorm
3. Run the normalization substage before asking detailed questions:
   - parse the source material into `normalize.md` using the broad themes above
   - use stable `N-###` identifiers for material normalized facts
   - preserve explicit source commitments rather than abstracting them into high-level summaries
   - let the subtopics and local formats emerge from the source material instead of forcing one schema everywhere
   - maintain `## Source Coverage Index` so important source sections are not silently dropped
4. Run the memorandum capture substage alongside normalization:
   - record source-vs-code or source-vs-interface conflicts in `memorandum.md`
   - record user-deferred or explicitly excluded-for-now items in `memorandum.md`
   - record pending clarifications and blocked-by-external dependencies in `memorandum.md`
   - do not silently drop these items just because they are not entering the current PRD
5. Clarify one thing at a time:
   - ask one question per message
   - prefer multiple-choice questions when possible
   - ask against normalization gaps, requirement conflicts, memorandum blockers, or scope-changing uncertainties rather than generic brainstorming prompts
   - if a technical choice depends on patterns, specs, or likely touched files, first run formal Trellis research with explicit `subagent_type: "research"`, then present 2-3 feasible approaches with trade-offs
6. Expand briefly before converging:
   - consider likely future evolution
   - related scenarios or parity expectations
   - failure and edge cases that matter for MVP scope
7. Keep the Trellis task authoritative:
   - after each meaningful answer, update `normalize.md` first
   - update `memorandum.md` whenever an item becomes deferred, excluded, pending, blocked, resolved, or promoted
   - update `prd.md` only with the high-level direction, confirmed scope, and handoff-relevant summaries needed before `/trellis-sp:specify`
8. Confirm the normalized understanding before handoff:
   - summarize the goal, included scope, excluded scope, key decisions, and any remaining high-value ambiguities using the normalized material
   - explicitly call out the important items parked in `memorandum.md`
   - do not proceed until the user has confirmed the requirements summary
9. Adapter phase handoff:
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
