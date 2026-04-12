#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="${1:-}"

usage() {
  local exit_code="${1:-1}"
  printf 'Usage:\n' >&2
  printf '  %s <command> [args...]\n' "$0" >&2
  printf '\nCommands:\n' >&2
  printf '  bootstrap <trellis-project>\n' >&2
  printf '  install <trellis-project>\n' >&2
  printf '  uninstall <trellis-project>\n' >&2
  printf '  verify <trellis-project>\n' >&2
  printf '  restore <trellis-project> <snapshot-name>\n' >&2
  printf '  list-backups <trellis-project> [snapshot-name]\n' >&2
  printf '  status <trellis-project>\n' >&2
  printf '  prune-backups <trellis-project> <delete|keep-latest> <value>\n' >&2
  printf '  doctor <trellis-project>\n' >&2
  printf '  self-test <trellis-project>\n' >&2
  printf '  export-manifest <trellis-project> [output-path]\n' >&2
  printf '  release-check <trellis-project>\n' >&2
  exit "$exit_code"
}

if [[ -z "$COMMAND" ]]; then
  usage 1
fi

shift

case "$COMMAND" in
  bootstrap)
    exec "$SCRIPT_DIR/bootstrap.sh" "$@"
    ;;
  install)
    exec "$SCRIPT_DIR/install.sh" "$@"
    ;;
  uninstall)
    exec "$SCRIPT_DIR/uninstall.sh" "$@"
    ;;
  verify)
    exec "$SCRIPT_DIR/verify.sh" "$@"
    ;;
  restore)
    exec "$SCRIPT_DIR/restore.sh" "$@"
    ;;
  list-backups)
    exec "$SCRIPT_DIR/list-backups.sh" "$@"
    ;;
  status)
    exec "$SCRIPT_DIR/status.sh" "$@"
    ;;
  prune-backups)
    exec "$SCRIPT_DIR/prune-backups.sh" "$@"
    ;;
  doctor)
    exec "$SCRIPT_DIR/doctor.sh" "$@"
    ;;
  self-test)
    exec "$SCRIPT_DIR/self-test.sh" "$@"
    ;;
  export-manifest)
    exec "$SCRIPT_DIR/export-manifest.sh" "$@"
    ;;
  release-check)
    exec "$SCRIPT_DIR/release-check.sh" "$@"
    ;;
  help|-h|--help)
    usage 0
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$COMMAND" >&2
    usage 1
    ;;
esac
