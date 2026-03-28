#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"

print_help_details() {
  log_plain 'Notes:'
  print_native_gui_note
  print_headless_gui_note
  log_plain '  arnis is usually better started with ./scripts/docker/run.sh for one-shot CLI commands.'
  print_headless_helper_note
  log_plain
  print_examples_header
  log_plain '  ./scripts/docker/up.sh arnis-gui'
  log_plain '  ./scripts/docker/up.sh arnis-gui-headless'
  log_plain '  ./scripts/docker/up.sh -d arnis-gui'
  log_plain '  ./scripts/docker/up.sh arnis-test-live'
}

handle_compose_help "${1:-}" '[SERVICE...] [COMPOSE_UP_ARGS...]' 'Starts the Docker services defined in docker-compose.yml.' true print_help_details

if [ "$#" -eq 0 ]; then
  die "No service specified. Choose one of: arnis, arnis-gui, arnis-gui-headless, arnis-test-live"
elif ! [[ "${1:-}" == -* ]]; then
  require_known_service "${1:-}"
fi

if [ "${1:-}" = "arnis-gui" ] || { [ "${1:-}" = "-d" ] && [ "${2:-}" = "arnis-gui" ]; }; then
  ensure_native_gui_display
fi

run_compose up "$@"
