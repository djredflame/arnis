#!/usr/bin/env bash

[ "${ARNIS_DOCKER_COMPOSE_LOADED:-0}" = "1" ] && return 0
ARNIS_DOCKER_COMPOSE_LOADED=1

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

compose_base_args() {
  local override_file=""

  override_file="$(detect_os_compose_override_file)"

  COMPOSE_BASE_ARGS=(
    -f "${BASE_COMPOSE_FILE}"
  )

  if [ -n "${override_file}" ]; then
    COMPOSE_BASE_ARGS+=(-f "${override_file}")
  fi
}

run_compose() {
  compose_base_args
  cd "${REPO_ROOT}"

  if [ -f "${DOCKER_ENV_FILE}" ]; then
    docker compose --env-file "${DOCKER_ENV_FILE}" "${COMPOSE_BASE_ARGS[@]}" "$@"
  else
    docker compose "${COMPOSE_BASE_ARGS[@]}" "$@"
  fi
}

run_compose_with_env() {
  local env_name="$1"
  local env_value="$2"
  shift 2

  compose_base_args
  cd "${REPO_ROOT}"

  if [ -f "${DOCKER_ENV_FILE}" ]; then
    env "${env_name}=${env_value}" docker compose --env-file "${DOCKER_ENV_FILE}" "${COMPOSE_BASE_ARGS[@]}" "$@"
  else
    env "${env_name}=${env_value}" docker compose "${COMPOSE_BASE_ARGS[@]}" "$@"
  fi
}