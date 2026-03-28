#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"

print_help_details() {
  print_examples_header
  log_plain '  ./scripts/docker/ps.sh'
  log_plain '  ./scripts/docker/ps.sh --all'
}

handle_compose_help "${1:-}" '[COMPOSE_PS_ARGS...]' 'Lists the services managed by docker compose for this repository.' true print_help_details

run_compose ps "$@"
