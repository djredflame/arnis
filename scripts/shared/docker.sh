#!/usr/bin/env bash

set -Eeuo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SHARED_DIR}/../.." && pwd)"
DOCKER_ENV_FILE="${REPO_ROOT}/.env.docker"
DEFAULT_RUN_SERVICE="arnis"
BASE_COMPOSE_FILE="${REPO_ROOT}/docker-compose.yml"

# Keep explicit process-level override even when .env.docker provides defaults.
_ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_ORIG="${ARNIS_DISABLE_OS_COMPOSE_OVERRIDE-}"
_ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_WAS_SET="${ARNIS_DISABLE_OS_COMPOSE_OVERRIDE+x}"

# shellcheck disable=SC1091
source "${SHARED_DIR}/common.sh"

if [ -f "${DOCKER_ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${DOCKER_ENV_FILE}"
  set +a
fi

if [ "${_ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_WAS_SET}" = "x" ]; then
  ARNIS_DISABLE_OS_COMPOSE_OVERRIDE="${_ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_ORIG}"
fi

unset _ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_ORIG
unset _ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_WAS_SET

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

detect_display_id() {
  printf '%s\n' "${ARNIS_GUI_DISPLAY:-${DISPLAY:-:0}}"
}

detect_display_socket() {
  local display_id socket_id
  display_id="$(detect_display_id)"

  case "${display_id}" in
    :*)
      socket_id="${display_id#*:}"
      socket_id="${socket_id%%.*}"
      printf '/tmp/.X11-unix/X%s\n' "${socket_id}"
      ;;
    *)
      printf '\n'
      ;;
  esac
}

ensure_native_gui_display() {
  local display_id display_socket
  display_id="$(detect_display_id)"
  display_socket="$(detect_display_socket)"

  case "${display_id}" in
    :*)
      if [ -z "${display_socket}" ] || [ ! -S "${display_socket}" ]; then
        die "arnis-gui requires a local X11 display socket for DISPLAY=${display_id}. On headless Linux hosts, use ./scripts/docker/gui-headless.sh up instead."
      fi
      ;;
    *)
      die "arnis-gui expects a local X11 DISPLAY like :0. For headless Linux hosts, use ./scripts/docker/gui-headless.sh up instead."
      ;;
  esac
}

is_known_service() {
  case "${1:-}" in
    arnis|arnis-gui|arnis-gui-headless|arnis-test-live)
      return 0
      ;;
  esac
  return 1
}

require_known_service() {
  local service="${1:-}"

  case "${service}" in
    arnis|arnis-gui|arnis-gui-headless|arnis-test-live)
      return 0
      ;;
    *)
      die "Unknown service: ${service}"
      ;;
  esac
}

print_supported_services() {
  log_plain 'Supported services:'
  log_plain '  arnis              CLI generation and headless runs'
  log_plain '  arnis-gui          Linux desktop GUI only (requires X11 on the host)'
  log_plain '  arnis-gui-headless Linux desktop GUI over VNC (Docker-only headless path)'
  log_plain '  arnis-test-live    Full live test suite'
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

run_compose() {
  local override_file=""

  override_file="$(detect_os_compose_override_file)"

  cd "${REPO_ROOT}"

  local compose_args=(
    -f "${BASE_COMPOSE_FILE}"
  )

  if [ -n "${override_file}" ]; then
    compose_args+=(-f "${override_file}")
  fi

  if [ -f "${DOCKER_ENV_FILE}" ]; then
    docker compose --env-file "${DOCKER_ENV_FILE}" "${compose_args[@]}" "$@"
  else
    docker compose "${compose_args[@]}" "$@"
  fi
}

run_compose_with_env() {
  local env_name="$1"
  local env_value="$2"
  local override_file=""
  shift 2

  override_file="$(detect_os_compose_override_file)"

  cd "${REPO_ROOT}"

  local compose_args=(
    -f "${BASE_COMPOSE_FILE}"
  )

  if [ -n "${override_file}" ]; then
    compose_args+=(-f "${override_file}")
  fi

  if [ -f "${DOCKER_ENV_FILE}" ]; then
    env "${env_name}=${env_value}" docker compose --env-file "${DOCKER_ENV_FILE}" "${compose_args[@]}" "$@"
  else
    env "${env_name}=${env_value}" docker compose "${compose_args[@]}" "$@"
  fi
}

detect_os_compose_override_file() {
  local os_name=""
  local override_path=""

  if [ "${ARNIS_DISABLE_OS_COMPOSE_OVERRIDE:-0}" = "1" ]; then
    printf '\n'
    return 0
  fi

  os_name="$(uname -s 2>/dev/null || printf unknown)"

  case "${os_name}" in
    Darwin*)
      override_path="${REPO_ROOT}/docker-compose.mac.yml"
      ;;
    Linux*)
      override_path="${REPO_ROOT}/docker-compose.linux.yml"
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      override_path="${REPO_ROOT}/docker-compose.windows.yml"
      ;;
    *)
      override_path=""
      ;;
  esac

  if [ -n "${override_path}" ] && [ -f "${override_path}" ]; then
    printf '%s\n' "${override_path}"
    return 0
  fi

  printf '\n'
}
