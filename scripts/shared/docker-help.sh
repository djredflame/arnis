#!/usr/bin/env bash

[ "${ARNIS_DOCKER_HELP_LOADED:-0}" = "1" ] && return 0
ARNIS_DOCKER_HELP_LOADED=1

print_repo_hint() {
  log_plain "Runs from: ${REPO_ROOT}"
}

print_compose_env_hint() {
  log_plain 'Compose settings can be customized via .env.docker (see .env.docker.example).'
  log_plain 'OS-specific overrides are auto-loaded when present: docker-compose.mac.yml, docker-compose.linux.yml, docker-compose.windows.yml.'
}

print_native_gui_note() {
  log_plain '  arnis-gui requires a Linux desktop/X11 session on the host.'
}

print_headless_gui_note() {
  log_plain '  gui-headless.sh provides a Linux headless GUI path by combining a host X11/VNC display with the Dockerized arnis-gui service.'
}

print_headless_helper_note() {
  log_plain '  For headless Linux hosts, use ./scripts/docker/gui-headless.sh up instead.'
}

print_examples_header() {
  log_plain 'Examples:'
}

handle_compose_help() {
  local current_arg="$1"
  local usage="$2"
  local summary="$3"
  local include_services="${4:-false}"
  local callback="${5:-}"

  if ! is_help_flag "${current_arg}"; then
    return 0
  fi

  print_usage_header "${usage}"
  log_plain
  log_plain "${summary}"
  print_repo_hint
  log_plain
  print_compose_env_hint
  log_plain

  if [ "${include_services}" = "true" ]; then
    print_supported_services
    log_plain
  fi

  if [ -n "${callback}" ]; then
    "${callback}"
  fi

  exit 0
}