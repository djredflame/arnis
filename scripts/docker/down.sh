#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"

print_help_details() {
  print_examples_header
  log_plain '  ./scripts/docker/down.sh'
  log_plain '  ./scripts/docker/down.sh --remove-orphans'
}

handle_compose_help "${1:-}" '[COMPOSE_DOWN_ARGS...]' 'Stops services and removes compose resources for this repository.' false print_help_details

run_compose down "$@"
