#!/usr/bin/env bash

[ "${ARNIS_TEST_UNIT_SHARED_CORE_LOADED:-0}" = "1" ] && return 0
ARNIS_TEST_UNIT_SHARED_CORE_LOADED=1

run_unit_shared_core_tests() {
  output="$(ARNIS_LOG_COLOR=never ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"; log_info "test"
  ')"
  case "${output}" in
    *$'\033'*) die "logger: ARNIS_LOG_COLOR=never still produced ANSI codes" ;;
  esac

  output="$(NO_COLOR=1 ARNIS_LOG_COLOR=auto ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"; log_info "test"
  ')"
  case "${output}" in
    *$'\033'*) die "logger: NO_COLOR=1 still produced ANSI codes" ;;
  esac

  output="$(TERM=dumb ARNIS_LOG_COLOR=auto ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"; log_info "test"
  ')"
  case "${output}" in
    *$'\033'*) die "logger: TERM=dumb still produced ANSI codes" ;;
  esac

  output="$(ARNIS_LOG_COLOR=never ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"; log_info "hello"
  ')"
  assert_output_contains "${output}" "[INFO] hello" "log_info prefix"

  output="$(ARNIS_LOG_COLOR=never ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"; log_success "done"
  ')"
  assert_output_contains "${output}" "[OK] done" "log_success prefix"

  output="$(ARNIS_LOG_COLOR=never ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"; log_warn "careful"
  ' 2>&1)"
  assert_output_contains "${output}" "[WARN] careful" "log_warn on stderr"

  output="$(ARNIS_LOG_COLOR=never ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"; log_error "boom"
  ' 2>&1)"
  assert_output_contains "${output}" "[ERROR] boom" "log_error on stderr"

  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    is_help_flag "-h" && echo yes || echo no
  ' 2>/dev/null)"
  assert_output_contains "${output}" "yes" "is_help_flag -h"

  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    is_help_flag "--help" && echo yes || echo no
  ' 2>/dev/null)"
  assert_output_contains "${output}" "yes" "is_help_flag --help"

  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    is_help_flag "foo" && echo yes || echo no
  ' 2>/dev/null)"
  assert_output_contains "${output}" "no" "is_help_flag non-flag"

  trap - ERR
  exit_code=0
  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    die "test-error-message"
  ' 2>&1)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 1 ] || die "die: expected exit 1, got ${exit_code}"
  assert_output_contains "${output}" "test-error-message" "die message on stderr"

  for svc in arnis arnis-gui arnis-gui-headless arnis-test-live; do
    output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c "
      source \"\${ARNIS_UNIT_ROOT}/scripts/shared/docker.sh\"
      is_known_service '${svc}' && echo yes || echo no
    " 2>/dev/null)"
    assert_output_contains "${output}" "yes" "is_known_service ${svc}"
  done

  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/docker.sh"
    is_known_service "invalid-xyz" && echo yes || echo no
  ' 2>/dev/null)"
  assert_output_contains "${output}" "no" "is_known_service unknown returns false"

  trap - ERR
  exit_code=0
  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/docker.sh"
    require_known_service "bad-service"
  ' 2>&1)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -ne 0 ] || die "require_known_service: expected non-zero exit for unknown service"
  assert_output_contains "${output}" "Unknown service: bad-service" "require_known_service error message"

  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/docker.sh"
    ARNIS_GUI_DISPLAY=":0"; detect_display_socket
  ' 2>/dev/null)"
  assert_output_contains "${output}" "/tmp/.X11-unix/X0" "detect_display_socket :0"

  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/docker.sh"
    ARNIS_GUI_DISPLAY=":99"; detect_display_socket
  ' 2>/dev/null)"
  assert_output_contains "${output}" "/tmp/.X11-unix/X99" "detect_display_socket :99"

  output="$(ARNIS_DISABLE_OS_COMPOSE_OVERRIDE=1 ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/docker.sh"
    detect_os_compose_override_file
  ' 2>/dev/null)"
  [ -z "${output}" ] || die "detect_os_compose_override_file: DISABLE=1 should return empty, got '${output}'"
}