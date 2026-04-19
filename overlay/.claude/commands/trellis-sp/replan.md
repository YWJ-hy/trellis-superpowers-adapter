---
name: replan
description: Create a post-verification handling plan for an adapter-managed parent task
---

# Trellis-Superpowers Replan

Use a local post-verification replanning discipline adapted from Superpowers, but keep Trellis as the source of truth.

## Non-negotiable rules

- Require an active adapter-managed Trellis parent task. If `.trellis/.current-task` points to a managed child task, resolve its parent and restore `.trellis/.current-task` to that parent before continuing. If no adapter-managed parent task can be resolved, stop and tell the user to activate the parent task first.
- This command is only for work that has already gone through `/trellis-sp:execute` and later received post-execution human verification feedback or changed requirements.
- Treat the parent task `prd.md`, `trace.md`, and `info.md` as the authoritative reviewed execution artifacts.
- When requirement changes are involved, treat parent `normalize.md` as the source-faithful normalization ledger that must be refreshed before the reviewed PRD is re-formalized.
- Treat parent `memorandum.md` as the memo of deferred, excluded, conflicting, pending, blocked, resolved, or promoted items, and refresh it when requirement status changes materially.
- Reuse the existing parent task as the source of truth; do not create a parallel parent task for the same feature.
- Do not execute implementation directly in this command.
- Do not rewrite completed child tasks into unrelated work; prefer new follow-up child tasks for non-trivial corrective work.
- Treat child `task.json.status` values `completed` and `done` as already-finished history that corrective execution should skip by default.
- Do not create any parallel planning workspace, external change-request document, or command state outside `.trellis/tasks/`.
- Do not modify `.claude/settings.json`, Trellis hooks, or built-in `trellis/*` commands as part of this command.
- If this feedback reveals reusable project-wide rules, constraints, or debugging lessons, point to `/trellis:update-spec` as a later follow-up rather than changing `.trellis/spec/` during this command.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding. Treat the input as the latest human verification findings, requirement deltas, or both.

## Goal

Turn post-execution human verification feedback into a Trellis-native delta handling plan that reuses the existing parent task and safely hands back to `/trellis-sp:execute`.

## Workflow

1. Resolve the target parent context first.
   - confirm there is a current Trellis task
   - if the current task is a managed child with a recorded `parent`, restore `.trellis/.current-task` to that parent before continuing
   - confirm the parent task still has `meta.trellis_sp.managed=true` and `role="parent"`
   - read the parent `prd.md`
   - read the parent `info.md` if present
   - inspect the existing child-task structure and completed execution history as needed
   - immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase plan` once replanning begins
2. Triage the feedback into one internal branch before proposing changes:
   - `implementation deviation`
   - `requirement changed`
   - `mixed`
3. Branch rules for `implementation deviation`:
   - keep the parent `prd.md` stable unless the feedback proves the documented requirement is itself wrong
   - update the parent `info.md` with the verification findings, impacted scope, corrective plan, and verification targets
   - if the corrective work is reviewable or spans multiple files, prefer ordered follow-up child tasks instead of rewriting completed child tasks
4. Branch rules for `requirement changed`:
   - update the affected sections of parent `memorandum.md` first when item status changes, especially for deferred, excluded, pending, blocked, resolved, or promoted items
   - update the affected sections of parent `normalize.md` next so the source-faithful requirement ledger reflects the new requirement state
   - then update the parent `prd.md`
   - update the parent `trace.md` next so changed or newly introduced `D-###`, `FR-###`, and `SC-###` rows remain historically auditable
   - reuse `/trellis-sp:specify` and `/trellis-sp:clarify` discipline on only the affected sections such as Goal, Requirements, Success Criteria, Out of Scope, or Clarifications
   - then update the parent `info.md` with the execution delta plan and verification strategy
   - create follow-up child tasks only for the new or changed execution units
5. Branch rules for `mixed`:
   - update the changed requirement portion of parent `memorandum.md` first when memo state must change
   - update the changed requirement portion of parent `normalize.md` next
   - update the parent `prd.md` for the changed requirement portion next
   - update the parent `trace.md` so both changed requirements and prior proof state remain explicit
   - then record the remaining corrective execution delta in the parent `info.md`
   - create follow-up child tasks for any non-trivial implementation correction that should stay reviewable
6. Child-task handling rules:
   - preserve the history of previously completed child tasks
   - do not repurpose a completed child task into unrelated new scope
   - use new follow-up child tasks as the default corrective carrier instead of reopening already completed child tasks
   - when feedback maps cleanly to one reviewable delta, create a new child task with `python3 ./.trellis/scripts/task.py create "<title>" --slug <name> --parent <parent-task-dir>`
   - if you create a follow-up child task and its context files are missing, initialize them with `python3 ./.trellis/scripts/task.py init-context <child-task-dir> <dev_type>`
   - immediately run `python3 .claude/scripts/trellis-sp-task-meta.py <child-task-dir> --role child --phase execute --clear-resume`
   - each follow-up child task should narrow one corrective outcome in child `prd.md`, while child `info.md` records `Relevant Parent Context Slice`, `Read First`, likely touched files, sequencing, and verification targets
7. Decide whether child tasks are necessary.
   - if the corrective work is a truly atomic one-pass fix, a parent-only delta plan in parent `info.md` is acceptable
   - otherwise prefer ordered follow-up child tasks so `/trellis-sp:execute` can rerun the correction with normal review checkpoints
8. Write the delta handling plan back into Trellis task artifacts only.
   - update the parent `memorandum.md` only when the branch is `requirement changed` or `mixed`
   - update the parent `normalize.md` only when the branch is `requirement changed` or `mixed`
   - update the parent `prd.md` only when the branch is `requirement changed` or `mixed`
   - update the parent `trace.md` without silently overwriting prior proof history; preserve older rows and mark them changed, superseded, or still authoritative as appropriate
   - update the parent `info.md` with:
     - verification findings
     - branch classification
     - impacted files or code areas
     - ordered follow-up child tasks or parent-only corrective steps
     - verification strategy and stop conditions
   - determine the first pending corrective child task, skipping any child whose `task.json.status` is already `completed` or `done`
   - if there is a pending corrective child, keep the parent in a truthful replan-complete state with `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase replan --resume-source replan --resume-child <first-pending-child-dir>`
   - if corrective work is parent-only, clear the child cursor and keep only the parent-level corrective handoff state with `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase replan --resume-source replan --clear-resume`
9. End with the correct adapter handoff.
   - the default next step is `/trellis-sp:execute`
   - do not suggest `/trellis:finish-work` from this command
   - only after corrective execution restores the parent task and the parent-level final `check` passes cleanly may the workflow hand off to `/trellis:finish-work`

## Suggested input shapes

Use compact feedback input that makes the delta explicit.

### A. Implementation deviation

```text
人工验收发现实现偏差：
- 当前结果：按钮点击后直接跳转详情页
- 期望结果：先弹确认框，再进入详情页
- 需求本身未变
- 只影响前端交互，不改接口
```

### B. Requirement changed

```text
需求有变更：
- 原要求：创建后自动发布
- 新要求：创建后默认进入草稿
- 保留不变：现有表单字段和校验规则
- 需要重新评估受影响的 child tasks
```

### C. Mixed

```text
这次既有需求变更也有实现偏差：
- 原要求：支持批量删除
- 新要求：只允许批量归档，不允许删除
- 当前实现问题：列表页仍显示“删除”按钮且调用删除接口
- 需要给出最小修正方案
```

## Writing guidance

- Keep requirement edits minimal, explicit, and local to the affected sections.
- Prefer concise delta planning over rewriting the whole parent `info.md` or all child artifacts.
- If the feedback is underspecified, ask focused questions before changing the PRD or creating follow-up child tasks.
- Preserve the existing execution history whenever possible so the second pass remains auditable.
- After the corrective execution path is finished, evaluate whether the lessons learned should be promoted via `/trellis:update-spec` or summarized with `/trellis:record-session`.