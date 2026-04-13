#!/usr/bin/env python3
"""Stamp Trellis-Superpowers adapter metadata into task.json."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Update task.json meta.trellis_sp for adapter-managed tasks."
    )
    parser.add_argument("task", help="Task directory name, relative path, or absolute path")
    parser.add_argument(
        "--repo-root",
        help="Repository root containing .trellis/. Defaults to auto-detect from cwd.",
    )
    parser.add_argument(
        "--role",
        choices=("parent", "child"),
        required=True,
        help="Adapter role for the target task.",
    )
    parser.add_argument(
        "--phase",
        choices=("brainstorm", "specify", "clarify", "plan", "execute"),
        required=True,
        help="Latest adapter phase to record.",
    )
    parser.add_argument(
        "--managed",
        dest="managed",
        action="store_true",
        default=True,
        help="Mark task as adapter-managed (default).",
    )
    parser.add_argument(
        "--unmanaged",
        dest="managed",
        action="store_false",
        help="Clear adapter-managed flag while keeping the metadata block.",
    )
    parser.add_argument(
        "--workflow-version",
        type=int,
        default=1,
        help="Adapter workflow metadata version. Defaults to 1.",
    )
    return parser


def find_repo_root(start: Path) -> Path:
    current = start.resolve()
    while current != current.parent:
        if (current / ".trellis").is_dir():
            return current
        current = current.parent
    raise SystemExit(f"Could not find repository root from {start}")


def normalize_task_ref(task_ref: str) -> str:
    normalized = task_ref.strip()
    if not normalized:
        raise SystemExit("Task reference cannot be empty")

    path = Path(normalized)
    if path.is_absolute():
        return str(path)

    normalized = normalized.replace("\\", "/")
    while normalized.startswith("./"):
        normalized = normalized[2:]

    if normalized.startswith("tasks/"):
        return f".trellis/{normalized}"

    return normalized


def resolve_task_dir(task_ref: str, repo_root: Path) -> Path:
    normalized = normalize_task_ref(task_ref)
    path = Path(normalized)
    if path.is_absolute():
        return path
    if normalized.startswith(".trellis/"):
        return repo_root / path
    return repo_root / ".trellis" / "tasks" / path


def load_task_json(task_dir: Path) -> dict:
    task_json = task_dir / "task.json"
    if not task_json.is_file():
        raise SystemExit(f"task.json not found: {task_json}")
    try:
        return json.loads(task_json.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Failed to parse {task_json}: {exc}") from exc


def save_task_json(task_dir: Path, task_data: dict) -> None:
    task_json = task_dir / "task.json"
    task_json.write_text(json.dumps(task_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def update_meta(task_data: dict, *, role: str, phase: str, managed: bool, workflow_version: int) -> bool:
    changed = False

    meta = task_data.get("meta")
    if not isinstance(meta, dict):
        meta = {}
        task_data["meta"] = meta
        changed = True

    trellis_sp = meta.get("trellis_sp")
    if not isinstance(trellis_sp, dict):
        trellis_sp = {}
        meta["trellis_sp"] = trellis_sp
        changed = True

    desired = {
        "managed": managed,
        "role": role,
        "workflow_version": workflow_version,
        "last_phase": phase,
    }

    for key, value in desired.items():
        if trellis_sp.get(key) != value:
            trellis_sp[key] = value
            changed = True

    return changed


def main() -> int:
    args = build_parser().parse_args()
    repo_root = Path(args.repo_root).resolve() if args.repo_root else find_repo_root(Path.cwd())
    task_dir = resolve_task_dir(args.task, repo_root)
    if not task_dir.is_dir():
        raise SystemExit(f"Task directory not found: {task_dir}")

    task_data = load_task_json(task_dir)
    changed = update_meta(
        task_data,
        role=args.role,
        phase=args.phase,
        managed=args.managed,
        workflow_version=args.workflow_version,
    )
    if changed:
        save_task_json(task_dir, task_data)

    task_json = task_dir / "task.json"
    print(f"Updated trellis_sp metadata: {task_json}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as exc:  # pragma: no cover - defensive CLI boundary
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
