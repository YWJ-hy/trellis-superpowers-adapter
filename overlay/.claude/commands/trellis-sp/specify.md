---
name: specify
description: Create or refine a Trellis task spec from a feature description
---

# Trellis-Superpowers Specify

Use spec-kit-style spec authoring, but keep Trellis as the source of truth.

This command is adapted from spec-kit's `specify` workflow and spec template structure, but persists into the active Trellis task `prd.md` instead of creating spec-kit workspace artifacts.

## Non-negotiable rules

- Require an active Trellis task. If no task is active, stop and tell the user to create or start one with Trellis first.
- When `/trellis-sp:specify` is used, the active parent task must remain identifiable in `task.json` under `meta.trellis_sp`; ensure `managed=true`, `role="parent"`, `workflow_version=1`, and `last_phase="specify"` before finishing.
- Treat the active task's `prd.md` as the only persistent artifact for this command.
- Do not create any parallel spec workspace, external feature directory, or command state outside `.trellis/tasks/`.
- Do not modify `.claude/settings.json`, Trellis hooks, or built-in `trellis/*` commands as part of this command.
- Keep `.trellis/spec/` reserved for durable code-specs and guides. If this work uncovers reusable project rules, promote them later via `/trellis:update-spec`.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding. The text after `/trellis-sp:specify` is the feature description. If it is empty, fall back to the active task title and current `prd.md`. If all three are missing, stop and ask for a feature description.

## Goal

Turn the active Trellis task PRD into a clear, planning-ready feature spec using spec-kit discipline without introducing a second workflow system.

## Target document shape

The active task `prd.md` should converge toward this structure:

```markdown
# <Task Title>

## Goal

## User Scenarios & Testing

### User Story 1 - <Title> (Priority: P1)

### User Story 2 - <Title> (Priority: P2)

### Edge Cases

## Requirements

### Functional Requirements

### Key Entities

## Success Criteria

## Assumptions

## Out of Scope

## Technical Notes
```

Omit `### Key Entities` if the work does not involve meaningful data concepts.

## Workflow

1. Resolve the active Trellis task and open or create its `prd.md`.
   - ensure the active parent task remains marked in `task.json` under `meta.trellis_sp` with `managed=true`, `role="parent"`, `workflow_version=1`, and `last_phase="specify"`
   - immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase specify` before finishing this command so the active parent task stays adapter-identifiable
2. Parse the feature description, task title, and current PRD content.
   - Extract actors, actions, constraints, success signals, data concepts, and likely scope boundaries.
3. Preserve useful existing content.
   - Restructure and refine it.
   - Do not discard user-provided requirements unless you replace them with clearer equivalent text.
4. Build or refresh the PRD in this order:
   - `## Goal`
   - `## User Scenarios & Testing`
   - `## Requirements`
   - `## Success Criteria`
   - `## Assumptions`
   - `## Out of Scope`
   - `## Technical Notes`
5. For `## User Scenarios & Testing`:
   - prefer independently testable user journeys
   - prioritize them as P1 / P2 / P3 when possible
   - include concise Given / When / Then acceptance scenarios
   - include an `### Edge Cases` subsection for boundary and failure behavior
6. For `## Requirements`:
   - create specific, testable, unambiguous functional requirements
   - prefer requirement identifiers such as `FR-001`, `FR-002`, and so on
   - focus on **what** users need and **why** it matters
   - avoid implementation details such as frameworks, APIs, file layouts, code structure, or tool choices
7. For `### Key Entities`:
   - include only when the feature depends on data concepts, roles, records, or stateful objects
   - describe each entity in product terms, not schema terms
8. For `## Success Criteria`:
   - define measurable, user-facing, technology-agnostic outcomes
   - prefer identifiers such as `SC-001`, `SC-002`, and so on
   - make each criterion verifiable without knowledge of the implementation
9. For `## Assumptions` and `## Out of Scope`:
   - record reasonable defaults when details were not specified
   - make scope boundaries explicit so planning can stay focused
10. Handle ambiguity with disciplined defaults.
   - Make informed guesses when a reasonable default exists.
   - Only insert `[NEEDS CLARIFICATION: ...]` when the missing answer materially changes scope, security/privacy, core UX, or validation strategy.
   - Keep at most 3 unresolved clarification markers.
11. Run a quality pass on the PRD before asking the user anything.
   - Fix any issue you can fix directly.
   - Validate against this checklist:
     - no implementation details leaked into requirements
     - mandatory sections are present
     - user scenarios are understandable and independently testable
     - requirements are testable and unambiguous
     - success criteria are measurable and technology-agnostic
     - edge cases are identified
     - assumptions and out-of-scope are explicit
     - no more than 3 clarification markers remain
12. If critical clarifications remain after the quality pass:
   - ask at most 3 questions total
   - present all remaining high-value questions together in one response
   - for each question include:
     - a short topic label
     - the relevant PRD context
     - what must be decided
     - 2-3 concrete suggested answers plus a custom option when helpful
   - make it easy for the user to answer in compact form such as `Q1: A, Q2: Custom - ...`
13. After the user answers:
   - replace each clarification marker
   - update the relevant PRD sections immediately
   - re-run the quality pass
14. End with a completion summary that includes:
   - the active task `prd.md` path
   - whether the PRD is ready for planning
   - whether any ambiguity remains
   - the next Trellis-native step: `/trellis-sp:clarify` or `/trellis-sp:plan`
15. Adapter path handoff rules:
   - `/trellis-sp:specify` is part of the adapter lane entered from `/trellis-sp:brainstorm` or called directly on an already-active parent task
   - do not redirect the user back to `/trellis:brainstorm` once the adapter path is active
   - if high-value ambiguities remain, hand off to `/trellis-sp:clarify`
   - if the PRD is planning-ready, hand off to `/trellis-sp:plan`
   - do not suggest `/trellis:finish-work` from this command; finish happens only after execution completes, the parent task is restored, and the parent-level final `check` is clean

## Writing guidance

- Reuse strong parts of the current `prd.md` instead of rewriting for style.
- Prefer concise bullets and short paragraphs over long narrative prose.
- Keep the PRD task-local. Do not create new files or external command state.
- If durable project-wide implementation rules emerge, mention `/trellis:update-spec` as a later follow-up rather than changing `.trellis/spec/` during this command.
