#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"

print_help() {
  log_plain 'When no SERVICE is given, docker compose rm applies to all stopped services.'
  log_plain
  print_examples_header
  log_plain '  ./scripts/docker/rm.sh'
  log_plain '  ./scripts/docker/rm.sh arnis-gui'
  log_plain '  ./scripts/docker/rm.sh arnis arnis-test-live'
}

handle_compose_help "${1:-}" '[SERVICE...] [COMPOSE_RM_ARGS...]' 'Removes stopped service containers.' true print_help

# Remove stopped containers together with anonymous volumes.
run_compose rm -fsv "$@"
