# Changelog

## 1.8.0
- Added a managed `start.md` interoperability patch so `/trellis-sp:brainstorm` is recognized as the adapter's valid brainstorm path after `/trellis:start`.
- Extended install, uninstall, restore, verify, manifest, status, doctor, and backup inspection flows to track patch-managed files separately from overlay-owned files.
- Preserved explicit Trellis research routing with `subagent_type: "research"` across the adapter flow while keeping the patch minimal and reversible.
- Tightened `/trellis-sp:plan` so broad planning-ready work is explicitly decomposed into atomic parent/child Trellis tasks instead of remaining a single opaque execution pass.
- Tightened `/trellis-sp:execute` so child tasks are executed progressively with review checkpoints and a parent-level final `check`.
- Added concrete parent `info.md`, child `prd.md`, child-context, and execution-checklist templates to the overlay/docs.
- Strengthened `verify.sh` so the installed runtime must contain the atomic workflow contract, artifact templates, and execution checklist guidance.
- Updated README and Chinese integration docs with atomic child-task examples and operator-facing templates.

## 1.6.0
- Removed runtime dependency on `superpowers:*` skills from the `/trellis-sp:*` overlay commands.
- Localized brainstorming, planning, and execution guidance inside the adapter so users do not need to install Superpowers.
- Updated adapter metadata and verification rules to reject runtime Superpowers skill references in installed adapter files.
- Revised adapter documentation to explain the decoupled design and Trellis-safe workflow contract.

## 1.5.0
- Added `/trellis-sp:specify` for Trellis-native task PRD spec authoring.
- Added `/trellis-sp:clarify` for Trellis-native task PRD clarification.
- Updated adapter install/verify flows to include the new commands and reject spec-kit workspace artifact drift.
- Updated planning/docs text so Trellis task `prd.md` remains the single source of truth for task-level specs.
- Documented that `/trellis-sp:specify` and `/trellis-sp:clarify` are adapted from spec-kit methodology but rewritten to persist into Trellis task PRDs.
- Fixed `list-backups.sh` so a healthy install with no snapshots is treated as a successful empty state.

## 1.4.0
- Added `release-check.sh` to run a release-oriented validation pass.
- Added changelog tracking for the adapter package.

## 1.3.0
- Added `bootstrap.sh` for first-run and repeat-safe setup.
- Added `manage.sh bootstrap` routing.

## 1.2.0
- Added `export-manifest.sh` for machine-readable adapter state export.
- Added `manage.sh export-manifest` routing.

## 1.1.0
- Added `self-test.sh` for read-only smoke testing through the unified manage entrypoint.

## 1.0.0
- Added `manage.sh` as the unified adapter command entrypoint.
- Promoted the adapter toolchain to a single-command operational interface.

## 0.9.0
- Added `doctor.sh` for health diagnosis and next-step recommendations.

## 0.8.0
- Added `prune-backups.sh` for deleting named snapshots or keeping only the newest N snapshots.

## 0.7.0
- Added `status.sh` to summarize install state, verify results, Trellis version, and recent snapshots.

## 0.6.0
- Added snapshot metadata support via `snapshot.json`.
- Extended backup listing to show metadata-aware snapshots while remaining compatible with legacy snapshots.

## 0.5.0
- Added `list-backups.sh` to enumerate snapshots and inspect snapshot contents.

## 0.4.1
- Added `restore.sh` and adjusted restore behavior to support partial snapshots safely.

## 0.4.0
- Added restore lifecycle support and integrated restore documentation.

## 0.3.0
- Added conflict protection for install.
- Added force-overwrite and backup behavior for conflicting adapter-managed files.

## 0.2.0
- Added compatibility checks and dry-run support for install/verify/uninstall.
- Added adapter metadata via `adapter.json`.

## 0.1.0
- Initial pluggable Trellis-Superpowers adapter prototype.
- Added wrapper commands for brainstorming, planning, and execution.
- Added local adapter skill and install overlay structure.
