#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"

print_help_details() {
  log_plain 'When no SERVICE is given, all compose build targets are built.'
  log_plain 'Build-time validation is optional and disabled by default for faster local builds.'
  log_plain
  print_examples_header
  log_plain '  ./scripts/docker/build.sh'
  log_plain '  ./scripts/docker/build.sh --with-tests'
  log_plain '  ./scripts/docker/build.sh --without-tests arnis-gui-headless'
  log_plain '  ./scripts/docker/build.sh arnis'
  log_plain '  ./scripts/docker/build.sh arnis-gui'
  log_plain '  ./scripts/docker/build.sh arnis-test-live'
}

handle_compose_help "${1:-}" '[--with-tests|--without-tests] [SERVICE...] [COMPOSE_BUILD_ARGS...]' 'Builds the Docker images defined in docker-compose.yml.' true print_help_details

validation_mode="${ARNIS_RUN_BUILD_VALIDATION:-0}"
build_args=()

for arg in "$@"; do
  case "${arg}" in
    --with-tests)
      validation_mode="1"
      ;;
    --without-tests)
      validation_mode="0"
      ;;
    *)
      build_args+=("${arg}")
      ;;
  esac
done

if [ "${validation_mode}" = "1" ]; then
  log_info 'Building with build-time cargo test validation enabled.'
else
  log_info 'Building without build-time cargo test validation.'
fi

if [ "${#build_args[@]}" -gt 0 ]; then
  run_compose_with_env ARNIS_RUN_BUILD_VALIDATION "${validation_mode}" build "${build_args[@]}"
else
  run_compose_with_env ARNIS_RUN_BUILD_VALIDATION "${validation_mode}" build
fi
