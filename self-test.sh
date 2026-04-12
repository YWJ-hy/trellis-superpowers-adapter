#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ARG="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_ARG" && pwd)"

printf 'Self-test: verify\n'
"$SCRIPT_DIR/manage.sh" verify "$TARGET_DIR"

printf '\nSelf-test: status\n'
"$SCRIPT_DIR/manage.sh" status "$TARGET_DIR"

printf '\nSelf-test: doctor\n'
"$SCRIPT_DIR/manage.sh" doctor "$TARGET_DIR"

printf '\nSelf-test: list-backups\n'
"$SCRIPT_DIR/manage.sh" list-backups "$TARGET_DIR"

printf '\nSelf-test completed successfully\n'
