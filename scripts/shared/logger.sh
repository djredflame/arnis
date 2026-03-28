#!/usr/bin/env bash

if [ "${SHARED_LOGGER_LOADED:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

SHARED_LOGGER_LOADED=1

# Keep terminal output readable and neutral for a general-purpose upstream
# project. Colors only decorate the level prefix and only when the output
# target actually supports ANSI colors.
LOGGER_COLOR_MODE="${ARNIS_LOG_COLOR:-auto}"
LOGGER_RESET=$'\033[0m'
LOGGER_INFO=$'\033[1;34m'
LOGGER_SUCCESS=$'\033[1;32m'
LOGGER_WARN=$'\033[1;33m'
LOGGER_ERROR=$'\033[1;31m'
LOGGER_NOTE=$'\033[1;36m'
LOGGER_DIM=$'\033[2m'

logger_should_colorize() {
  local fd="${1:-1}"

  case "${LOGGER_COLOR_MODE}" in
    always)
      return 0
      ;;
    never)
      return 1
      ;;
    auto)
      ;;
    *)
      return 1
      ;;
  esac

  if [ -n "${NO_COLOR:-}" ] || [ "${TERM:-}" = "dumb" ]; then
    return 1
  fi

  [ -t "${fd}" ]
}

logger_emit() {
  local stream="${1:-stdout}"
  local level="${2:-INFO}"
  local color="${3:-}"
  shift 3

  local prefix="[${level}]"
  local output_fd="1"

  if [ "${stream}" = "stderr" ]; then
    output_fd="2"
  fi

  if logger_should_colorize "${output_fd}" && [ -n "${color}" ]; then
    printf '%b%s%b %s\n' "${color}" "${prefix}" "${LOGGER_RESET}" "$*" >&"${output_fd}"
  else
    printf '%s %s\n' "${prefix}" "$*" >&"${output_fd}"
  fi
}

log_info() {
  logger_emit stdout INFO "${LOGGER_INFO}" "$*"
}

log_success() {
  logger_emit stdout OK "${LOGGER_SUCCESS}" "$*"
}

log_warn() {
  logger_emit stderr WARN "${LOGGER_WARN}" "$*"
}

log_error() {
  logger_emit stderr ERROR "${LOGGER_ERROR}" "$*"
}

log_note() {
  logger_emit stdout NOTE "${LOGGER_NOTE}" "$*"
}

log_note_stderr() {
  logger_emit stderr NOTE "${LOGGER_NOTE}" "$*"
}

log_plain() {
  printf '%s\n' "$*"
}
