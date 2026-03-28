#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logger.sh"

handle_unexpected_error() {
  local exit_code="$1"
  local line_no="$2"
  local command="$3"

  if [ "${exit_code}" -eq 0 ]; then
    return 0
  fi

  log_error "$(script_name) failed."
  log_note_stderr "Exit code: ${exit_code}"
  log_note_stderr "Line: ${line_no}"
  log_note_stderr "Command: ${command}"

  exit "${exit_code}"
}

install_error_trap() {
  if [ "${SHARED_ERROR_TRAP_INSTALLED:-0}" = "1" ]; then
    return 0
  fi

  SHARED_ERROR_TRAP_INSTALLED=1
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
}

script_name() {
  basename "$0"
}

is_help_flag() {
  [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]
}

print_usage_header() {
  log_plain "Usage: $(script_name) $1"
}

die() {
  log_error "$*"
  exit 1
}

install_error_trap
