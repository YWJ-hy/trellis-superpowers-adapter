---
name: specify
description: Create or refine a Trellis task spec from a feature description
---

# Trellis-Superpowers Specify

Use spec-kit-style spec authoring, but keep Trellis as the source of truth.

This command is adapted from spec-kit's `specify` workflow and spec template structure, but persists into the active Trellis task `prd.md` instead of creating spec-kit workspace artifacts.

## Non-negotiable rules

- Require an active Trellis task. If no task is active, stop and tell the user to create or start one with Trellis first.
- When `/trellis-sp:specify` is used, the active parent task must remain identifiable in `task.json` under `meta.trellis_sp`; ensure `managed=true`, `role="parent"`, `workflow_version=2`, and `last_phase="specify"` before finishing.
- Treat the active task's reviewed `prd.md` as the authoritative output artifact for this command.
- Consume the parent task `normalize.md` as the primary normalization input when it exists.
- Read parent `memorandum.md` as the secondary memo input so deferred, excluded, conflicting, or pending items do not accidentally become committed scope.
- Do not create any parallel spec workspace, external feature directory, or command state outside `.trellis/tasks/`.
- Do not modify `.claude/settings.json`, Trellis hooks, or built-in `trellis/*` commands as part of this command.
- Keep `.trellis/spec/` reserved for durable code-specs and guides. If this work uncovers reusable project rules, promote them later via `/trellis:update-spec`.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding. The text after `/trellis-sp:specify` is the feature description. If it is empty, fall back to the active task title and current `prd.md`. If all three are missing, stop and ask for a feature description.

## Goal

Turn the active Trellis task's normalized requirements into a clear, planning-ready feature spec using spec-kit discipline without introducing a second workflow system.

## Normalization-aware contract

`/trellis-sp:specify` is no longer the first place where messy source material gets interpreted. When parent `normalize.md` exists, it is the primary input to formalize. Raw PRD text, pasted source text, and earlier conversation should be treated as supporting material and consistency checks, not as the main source of truth for formalization.

This command must prove that material normalized facts were carried forward into the reviewed `prd.md` as one of:
- user scenarios
- `FR-###`
- `SC-###`
- `D-###`
- edge cases
- assumptions
- out-of-scope notes

Material normalized facts should not survive only implicitly.

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

## Critical Details to Preserve

## Assumptions

## Out of Scope

## Spec Review Gate

## Technical Notes
```

Omit `### Key Entities` if the work does not involve meaningful data concepts.

Use stable identifiers once they are introduced:
- functional requirements → `FR-001`, `FR-002`, and so on
- success criteria → `SC-001`, `SC-002`, and so on
- critical detail rows → `D-001`, `D-002`, and so on

`## Critical Details to Preserve` is required whenever rich upstream input contains nuanced details that are easy to lose during normalization, such as field-level constraints, module-specific interactions, attachment or rich-text placement, defaults, edge-case caveats, or integration assumptions.

For frontend projects, any source requirement that explicitly names UI controls, components, or interaction containers must be preserved as mandatory `D-###` details rather than collapsed into generic summaries. This includes, at minimum, tables, table columns, row actions, input fields, search forms, selectors, date pickers, upload controls, editors, tabs, drawers, modals/dialogs, trees, cards, and similar named UI surfaces.

`## Spec Review Gate` is required before planning handoff. It should truthfully record whether the written PRD is still pending review, approved for `/trellis-sp:plan`, or stale because later clarifications materially changed the documented behavior.

## Workflow

1. Resolve the active Trellis task and open or create its `prd.md`.
   - ensure the active parent task remains marked in `task.json` under `meta.trellis_sp` with `managed=true`, `role="parent"`, `workflow_version=2`, and `last_phase="specify"`
   - immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase specify` before finishing this command so the active parent task stays adapter-identifiable
2. Resolve the formalization inputs.
   - read parent `normalize.md` when it exists
   - read parent `memorandum.md` when it exists
   - read the current `prd.md`
   - consider any new user input as additive prioritization or correction context
   - use raw source text only as a consistency check when the normalized ledger appears incomplete or contradictory
   - treat memorandum items with statuses such as `deferred`, `excluded-for-now`, `pending-confirmation`, or `blocked-by-external` as non-committed unless the user explicitly promotes them
3. Preserve useful existing content.
   - Restructure and refine it.
   - Do not discard user-provided requirements unless you replace them with clearer equivalent text.
   - When `normalize.md` exists, prefer formalizing from normalized facts instead of re-summarizing the source from scratch.
   - When `memorandum.md` exists, do not pull deferred, excluded, pending, or externally blocked items into the committed PRD unless they have been re-confirmed and promoted.
4. Build or refresh the PRD in this order:
   - `## Goal`
   - `## User Scenarios & Testing`
   - `## Requirements`
   - `## Success Criteria`
   - `## Critical Details to Preserve`
   - `## Assumptions`
   - `## Out of Scope`
   - `## Spec Review Gate`
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
9. For `## Critical Details to Preserve`:
   - include only details whose loss would plausibly cause the implemented result to diverge from the upstream request
   - prefer stable identifiers such as `D-001`, `D-002`, and so on
   - preserve nuanced but implementation-relevant details such as field-level constraints, module-specific interactions, placement requirements, defaults, exceptions, and verification caveats
   - for frontend projects, preserve any explicitly named UI control, component, or interaction container as a first-class detail instead of abstracting it into generic phrasing
   - if the source requirement says `drawer`, `tab`, `upload`, `editor`, `table`, or another specific UI concept, keep that exact concept unless the requirement is intentionally changed through review or replan
   - keep the entries concise, but do not collapse multiple materially different details into one vague bullet
10. For `## Assumptions` and `## Out of Scope`:
   - record reasonable defaults when details were not specified
   - make scope boundaries explicit so planning can stay focused
11. For `## Spec Review Gate`:
   - record the current review status of the written PRD
   - use a compact format such as `Status: pending review`, `Status: approved for /trellis-sp:plan`, or `Status: stale after clarification`
   - if later clarifications materially change the spec, update the status so planning does not proceed on a stale review
12. Handle ambiguity with disciplined defaults.
   - Make informed guesses when a reasonable default exists.
   - Only insert `[NEEDS CLARIFICATION: ...]` when the missing answer materially changes scope, security/privacy, core UX, or validation strategy.
   - Keep at most 3 unresolved clarification markers.
13. Run a quality pass on the PRD before asking the user anything.
   - Fix any issue you can fix directly.
   - Validate against this checklist:
     - no implementation details leaked into requirements
     - mandatory sections are present
     - user scenarios are understandable and independently testable
     - requirements are testable and unambiguous
     - success criteria are measurable and technology-agnostic
     - critical details that would be easy to lose are explicitly preserved
     - explicitly named frontend UI controls/components remain preserved rather than abstracted away
     - edge cases are identified
     - assumptions and out-of-scope are explicit
     - `Spec Review Gate` truthfully reflects whether planning may proceed
     - no more than 3 clarification markers remain
14. If critical clarifications remain after the quality pass:
   - ask at most 3 questions total
   - present all remaining high-value questions together in one response
   - for each question include:
     - a short topic label
     - the relevant PRD context
     - what must be decided
     - 2-3 concrete suggested answers plus a custom option when helpful
   - make it easy for the user to answer in compact form such as `Q1: A, Q2: Custom - ...`
15. After the user answers:
   - replace each clarification marker
   - update the relevant PRD sections immediately
   - if the new answer materially changes the documented behavior, defaults, exclusions, preserved critical details, or named frontend UI controls/components, update `## Spec Review Gate` to a stale-review state until the written PRD is re-reviewed
   - re-run the quality pass
16. End with a completion summary that includes:
   - the active task `prd.md` path
   - whether the PRD is ready for planning
   - whether any ambiguity remains
   - whether `## Spec Review Gate` allows direct handoff to `/trellis-sp:plan`
   - the next Trellis-native step: `/trellis-sp:clarify` or `/trellis-sp:plan`
17. Adapter path handoff rules:
   - `/trellis-sp:specify` is part of the adapter lane entered from `/trellis-sp:brainstorm` or called directly on an already-active parent task
   - do not redirect the user back to `/trellis:brainstorm` once the adapter path is active
   - if high-value ambiguities remain, hand off to `/trellis-sp:clarify`
   - if the PRD is planning-ready, hand off to `/trellis-sp:plan`
   - do not suggest `/trellis:finish-work` from this command; finish happens only after execution completes, the parent task is restored, and the parent-level final `check` is clean

## Writing guidance

- Reuse strong parts of the current `prd.md` instead of rewriting for style.
- Prefer concise bullets and short paragraphs over long narrative prose.
- Keep the PRD task-local. Do not create new files or external command state.
- Preserve upstream nuance in `## Critical Details to Preserve` instead of hoping it survives indirectly through abstract requirements alone.
- For frontend work, preserve explicitly named UI controls/components with their original semantics instead of replacing them with generic wording.
- Do not describe the PRD as planning-ready when `## Spec Review Gate` is still pending or stale.
- If durable project-wide implementation rules emerge, mention `/trellis:update-spec` as a later follow-up rather than changing `.trellis/spec/` during this command.
