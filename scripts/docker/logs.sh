#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"

print_help_details() {
  log_plain 'Notes:'
  print_native_gui_note
  log_plain '  For headless Linux hosts, use ./scripts/docker/gui-headless.sh logs.'
  log_plain
  print_examples_header
  log_plain '  ./scripts/docker/logs.sh arnis-gui'
  log_plain '  ./scripts/docker/logs.sh arnis-gui-headless'
  log_plain '  ./scripts/docker/logs.sh -f arnis-test-live'
}

handle_compose_help "${1:-}" '[SERVICE...] [COMPOSE_LOG_ARGS...]' 'Shows logs for one or more services.' true print_help_details

if [ "$#" -eq 0 ]; then
  die "No service specified. Choose one of: arnis, arnis-gui, arnis-gui-headless, arnis-test-live"
elif ! [[ "${1:-}" == -* ]]; then
  require_known_service "${1:-}"
fi

run_compose logs "$@"
