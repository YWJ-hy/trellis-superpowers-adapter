---
name: clarify
description: Clarify the active Trellis task spec in place
---

# Trellis-Superpowers Clarify

Use spec-kit-style clarification, but keep Trellis as the source of truth.

This command is adapted from spec-kit's `clarify` workflow, but applies clarifications directly to the active Trellis task `prd.md` instead of using spec-kit workspace state.

## Non-negotiable rules

- Require an active Trellis task with an existing `prd.md`. If the PRD does not exist or is too thin to clarify, stop and tell the user to run `/trellis-sp:specify` or expand the task first.
- Treat the active task's `prd.md` as the only persistent artifact for this command.
- Keep the active parent task identifiable in `task.json` under `meta.trellis_sp`; ensure `managed=true`, `role="parent"`, `workflow_version=2`, and `last_phase="clarify"` before finishing.
- Do not create any parallel spec workspace, external feature directory, or command state outside `.trellis/tasks/`.
- Do not modify `.claude/settings.json`, Trellis hooks, or built-in `trellis/*` commands as part of this command.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding. Use any extra user input as prioritization context for what to clarify first.

## Goal

Identify the highest-impact ambiguities in the current task PRD and resolve them directly inside that same PRD.

## Ambiguity scan taxonomy

Scan the active task `prd.md` across these categories and mark each one internally as Clear / Partial / Missing:

### Functional Scope & Behavior
- core user goals and success conditions
- explicit out-of-scope declarations
- user roles or personas

### Domain & Data Model
- entities, attributes, and relationships
- identity or uniqueness rules
- lifecycle or state transitions
- scale or data volume assumptions

### Interaction & UX Flow
- critical user journeys
- empty, loading, and error states
- accessibility or localization notes when relevant

### Non-Functional Quality Attributes
- performance expectations
- scalability expectations
- reliability and recovery expectations
- observability needs
- security and privacy constraints
- compliance or regulatory constraints

### Integrations & Dependencies
- external systems or APIs
- import/export formats
- protocol or versioning assumptions
- failure modes and fallback expectations

### Edge Cases & Failure Handling
- negative scenarios
- throttling, quotas, or rate limits
- conflict resolution such as concurrent edits

### Constraints & Tradeoffs
- explicit technical or operational constraints
- chosen tradeoffs or rejected alternatives

### Terminology & Consistency
- canonical terms
- ambiguous synonyms
- placeholders or vague adjectives

### Completion Signals
- acceptance criteria testability
- measurable readiness and success indicators

## Workflow

1. Resolve the active Trellis task and read its `prd.md` once at the start.
   - ensure the active parent task remains marked in `task.json` under `meta.trellis_sp` with `managed=true`, `role="parent"`, `workflow_version=2`, and `last_phase="clarify"`
   - immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase clarify` before finishing this command so the active parent task stays adapter-identifiable
2. Perform the ambiguity scan taxonomy above.
3. Build an internal queue of candidate clarification questions.
   - ask only questions whose answers materially affect architecture, implementation, testing, UX behavior, operational readiness, or validation
   - skip low-impact stylistic or purely cosmetic questions
   - if more than 5 candidates exist, prioritize by impact × uncertainty
4. Ask at most 5 questions total and ask exactly one question at a time.
5. For multiple-choice questions:
   - provide 2-5 concrete options
   - mark the recommended option first with 1-2 sentences of reasoning
   - then render all options clearly in a small markdown table
   - allow a short custom answer when appropriate
6. For short-answer questions:
   - provide a suggested answer first with brief reasoning
   - request a reply in <=5 words when possible
7. If the user replies `yes`, `recommended`, or `suggested`, use the recommendation you already provided.
8. After each accepted answer:
   - ensure a `## Clarifications` section exists
   - ensure a `### Session YYYY-MM-DD` subsection exists for today
   - append `- Q: <question> → A: <final answer>`
   - immediately update the most relevant PRD section
   - replace contradictory older text instead of duplicating it
9. Use these integration rules when applying an answer:
   - scope or behavior changes → update `## Requirements` or `## User Scenarios & Testing`
   - actor or flow changes → update the relevant user story or acceptance scenario
   - data concept changes → update `### Key Entities`
   - measurable quality constraints → update `## Success Criteria`
   - nuanced implementation-relevant detail that would be easy to lose later → update `## Critical Details to Preserve`
   - edge-case answers → update `### Edge Cases`
   - terminology choices → normalize the chosen term throughout the PRD
   - keep existing `D-###`, `FR-###`, and `SC-###` identifiers stable whenever possible; extend them rather than renumbering prior rows
   - if a clarification materially changes documented behavior, defaults, exclusions, preserved critical details, or named frontend UI controls/components, update `## Spec Review Gate` to reflect that the written PRD needs re-review before planning
10. After each update, run a quick validation pass:
   - one clarification bullet per accepted answer
   - no contradictory earlier statement remains
   - no vague placeholder remains for the issue just clarified
   - section structure is still valid
   - total answered questions does not exceed 5
11. Stop when:
   - no critical ambiguities remain
   - the user says `stop`, `done`, or `proceed`
   - or 5 questions have been answered
12. If no meaningful questions are needed, say so clearly and recommend the next step without forcing more clarification.
13. End with a completion summary that includes:
   - number of questions asked and answered
   - the active task `prd.md` path
   - sections changed
   - a compact coverage summary using Clear / Resolved / Deferred / Outstanding
   - the next Trellis-native step, usually `/trellis-sp:plan`
14. Adapter path handoff rules:
   - `/trellis-sp:clarify` stays inside the adapter lane and should not send the user back to `/trellis:brainstorm`
   - when clarification resolves the remaining high-value ambiguities, the default next step is `/trellis-sp:plan`
   - do not suggest `/trellis:finish-work` from this command; finish belongs to the parent task after `/trellis-sp:execute` restores the parent and the parent-level final `check` passes cleanly

## Writing guidance

- Keep changes minimal, testable, and local to the active task `prd.md`.
- Preserve section order unless you need to add the missing `## Clarifications` section.
- Prefer measurable replacements for vague words such as `fast`, `robust`, or `intuitive`.
- Do not create new files or external command state.
- If the conversation reveals durable project-wide implementation rules, point to `/trellis:update-spec` as a later follow-up rather than changing `.trellis/spec/` during this command.
