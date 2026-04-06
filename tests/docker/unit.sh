#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"

log_info 'Running unit tests for shared scripts and entrypoint logic...'

# logger.sh: color suppression
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

# logger.sh: output labels + stream routing
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

# common.sh: is_help_flag
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

# common.sh: die exits 1 + message
trap - ERR
exit_code=0
output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  die "test-error-message"
' 2>&1)" || exit_code=$?
trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
[ "${exit_code}" -eq 1 ] || die "die: expected exit 1, got ${exit_code}"
assert_output_contains "${output}" "test-error-message" "die message on stderr"

# docker.sh: service checks
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

# docker.sh: display helpers
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

# headless-gui-entrypoint.sh: rule generation + lock cleanup
mock_bin="$(mktemp -d)"
for cmd in Xvfb xdpyinfo fluxbox x11vnc; do
  printf '#!/bin/sh\nexit 0\n' > "${mock_bin}/${cmd}"
  chmod +x "${mock_bin}/${cmd}"
done
state_dir="$(mktemp -d)"

ARNIS_HEADLESS_FULLSCREEN=1 \
ARNIS_HEADLESS_NO_TOOLBAR=1 \
ARNIS_HEADLESS_STATE_DIR="${state_dir}/on" \
ARNIS_HEADLESS_START_WAIT=1 \
ARNIS_GUI_VNC_PASSWORD="" \
PATH="${mock_bin}:${PATH}" \
  bash "${REPO_ROOT}/scripts/docker/headless-gui-entrypoint.sh" >/dev/null 2>&1 || true

apps_file="${state_dir}/on/home/.fluxbox/apps"
[ -f "${apps_file}" ] || die "entrypoint: FULLSCREEN=1 did not create fluxbox apps file"
output="$(cat "${apps_file}")"
assert_output_contains "${output}" "[Fullscreen] {yes}" "entrypoint FULLSCREEN=1: Fullscreen rule"
assert_output_contains "${output}" "[Maximized] {yes}" "entrypoint FULLSCREEN=1: Maximized rule"
assert_output_contains "${output}" "[Deco] {NONE}" "entrypoint FULLSCREEN=1: no decorations"
assert_output_contains "${output}" "[IgnoreSizeHints] {yes}" "entrypoint FULLSCREEN=1: ignore size hints"

ARNIS_HEADLESS_FULLSCREEN=0 \
ARNIS_HEADLESS_STATE_DIR="${state_dir}/off" \
ARNIS_HEADLESS_START_WAIT=1 \
ARNIS_GUI_VNC_PASSWORD="" \
PATH="${mock_bin}:${PATH}" \
  bash "${REPO_ROOT}/scripts/docker/headless-gui-entrypoint.sh" >/dev/null 2>&1 || true

apps_file="${state_dir}/off/home/.fluxbox/apps"
[ -f "${apps_file}" ] || die "entrypoint: FULLSCREEN=0 did not create fluxbox apps file"
[ ! -s "${apps_file}" ] || die "entrypoint: FULLSCREEN=0 apps file should be empty"

mkdir -p "/tmp/.X11-unix"
touch "/tmp/.X99-lock"
touch "/tmp/.X11-unix/X99"

ARNIS_HEADLESS_FULLSCREEN=0 \
ARNIS_HEADLESS_STATE_DIR="${state_dir}/locktest" \
ARNIS_HEADLESS_START_WAIT=1 \
ARNIS_GUI_VNC_PASSWORD="" \
PATH="${mock_bin}:${PATH}" \
  bash "${REPO_ROOT}/scripts/docker/headless-gui-entrypoint.sh" >/dev/null 2>&1 || true

[ ! -f "/tmp/.X99-lock" ] || die "entrypoint: stale /tmp/.X99-lock was not removed"
[ ! -e "/tmp/.X11-unix/X99" ] || die "entrypoint: stale /tmp/.X11-unix/X99 was not removed"

rm -rf "${mock_bin}" "${state_dir}"

log_success 'Unit tests passed.'
