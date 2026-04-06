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

# export-discovery.sh: parse discovered entries + render labels
output="$(ARNIS_LOG_COLOR=never ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-discovery.sh"
  list_worlds() {
    printf "dir:Arnis World 1\n"
    printf "mcworld:Arnis Pack.mcworld\n"
    printf "ignored:skip-me\n"
  }
  discover_worlds
  print_detected_worlds
  printf "COUNT=%s\n" "${#WORLD_TYPES[@]}"
  printf "FIRST=%s:%s\n" "${WORLD_TYPES[0]}" "${WORLD_NAMES[0]}"
  printf "SECOND=%s:%s\n" "${WORLD_TYPES[1]}" "${WORLD_NAMES[1]}"
')"
assert_output_contains "${output}" 'Detected worlds:' 'export-discovery print header'
assert_output_contains "${output}" '[DIR] Arnis World 1' 'export-discovery dir label'
assert_output_contains "${output}" '[MCWORLD] Arnis Pack.mcworld' 'export-discovery mcworld label'
assert_output_contains "${output}" 'COUNT=2' 'export-discovery parsed world count'
assert_output_contains "${output}" 'FIRST=dir:Arnis World 1' 'export-discovery first entry'
assert_output_contains "${output}" 'SECOND=mcworld:Arnis Pack.mcworld' 'export-discovery second entry'

trap - ERR
exit_code=0
output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-discovery.sh"
  list_worlds() { return 1; }
  discover_worlds && echo yes || echo no
' 2>&1)" || exit_code=$?
trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
[ "${exit_code}" -eq 0 ] || die "export-discovery failure path: unexpected exit ${exit_code}"
assert_output_contains "${output}" 'no' 'export-discovery returns false when list_worlds fails'

# export-conflict.sh: target detection + conflict modes
tmp_export_dir="$(mktemp -d)"
mkdir -p "${tmp_export_dir}/Arnis World 1" "${tmp_export_dir}/Arnis World 1 (copy)"
touch "${tmp_export_dir}/Pack.mcworld" "${tmp_export_dir}/Pack (copy).mcworld"

output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" ARNIS_TMP_EXPORT_DIR="${tmp_export_dir}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-conflict.sh"
  target_exists "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir && echo DIR_EXISTS=yes
  target_exists "${ARNIS_TMP_EXPORT_DIR}" "Pack" mcworld && echo MCWORLD_EXISTS=yes
  printf "COPY_DIR=%s\n" "$(generate_copy_name "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir)"
  printf "COPY_FILE=%s\n" "$(generate_copy_name "${ARNIS_TMP_EXPORT_DIR}" "Pack" mcworld)"
  printf "ASK_DEFAULT=%s\n" "$(resolve_conflict_name "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir ask </dev/null)"
  printf "OVERWRITE=%s\n" "$(resolve_conflict_name "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir overwrite)"
  printf "SKIP=%s\n" "$(resolve_conflict_name "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir skip)"
')"
assert_output_contains "${output}" 'DIR_EXISTS=yes' 'export-conflict target_exists dir'
assert_output_contains "${output}" 'MCWORLD_EXISTS=yes' 'export-conflict target_exists mcworld'
assert_output_contains "${output}" 'COPY_DIR=Arnis World 1 (copy 2)' 'export-conflict generate_copy_name dir'
assert_output_contains "${output}" 'COPY_FILE=Pack (copy 2)' 'export-conflict generate_copy_name mcworld'
assert_output_contains "${output}" 'ASK_DEFAULT=Arnis World 1 (copy 2)' 'export-conflict ask defaults to copy in non-interactive mode'
assert_output_contains "${output}" 'OVERWRITE=__OVERWRITE__' 'export-conflict overwrite marker'
assert_output_contains "${output}" 'SKIP=__SKIP__' 'export-conflict skip marker'

trap - ERR
exit_code=0
output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" ARNIS_TMP_EXPORT_DIR="${tmp_export_dir}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-conflict.sh"
  resolve_conflict_name "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir broken
' 2>&1)" || exit_code=$?
trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
[ "${exit_code}" -eq 1 ] || die "export-conflict invalid mode: expected exit 1, got ${exit_code}"
assert_output_contains "${output}" "Invalid conflict mode 'broken'" 'export-conflict invalid mode message'

output="$(printf '2\n' | ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-discovery.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-conflict.sh"
  WORLD_TYPES=(dir mcworld)
  WORLD_NAMES=("Arnis World 1" "Arnis Pack.mcworld")
  interactive_select
' 2>/dev/null)"
assert_output_contains "${output}" '1' 'export-conflict interactive_select returns selected index'

rm -rf "${tmp_export_dir}"

# export-io.sh: path conversion, lookup, and export dispatch
output="$(ARNIS_LOG_COLOR=never ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-io.sh"
  WORLD_TYPES=(dir mcworld dir)
  WORLD_NAMES=("Arnis World 1" "Arnis Pack.mcworld" "Second World")
  resolve_conflict_name() { printf "%s\n" "$2"; }
  export_world_dir() { printf "EXPORT_DIR:%s|%s|%s|%s\n" "$1" "$2" "$3" "$4"; }
  export_mcworld_file() { printf "EXPORT_FILE:%s|%s|%s\n" "$1" "$2" "$3"; }
  printf "PATH=%s\n" "$(to_docker_host_path /tmp/arnis-export)"
  printf "IDX_DIR=%s\n" "$(resolve_named_world_index "Arnis World 1")"
  printf "IDX_FILE=%s\n" "$(resolve_named_world_index "Arnis Pack")"
  export_entry_by_index 0 /tmp/out ask
  export_entry_by_index 1 /tmp/out ask
')"
path_line="$(printf '%s\n' "${output}" | grep '^PATH=' | head -n 1 || true)"
[ -n "${path_line}" ] || die 'export-io to_docker_host_path did not emit a PATH= line'
case "$(uname -s 2>/dev/null || printf unknown)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    case "${path_line}" in
      PATH=[A-Za-z]:/*|PATH=[A-Za-z]:\\*) ;;
      *) die "export-io to_docker_host_path expected a Windows-style host path, got '${path_line}'" ;;
    esac
    ;;
  *)
    [ "${path_line}" = 'PATH=/tmp/arnis-export' ] || die "export-io to_docker_host_path passthrough mismatch: ${path_line}"
    ;;
esac
assert_output_contains "${output}" 'IDX_DIR=0' 'export-io resolve_named_world_index exact dir'
assert_output_contains "${output}" 'IDX_FILE=1' 'export-io resolve_named_world_index mcworld alias'
assert_output_contains "${output}" 'EXPORT_DIR:Arnis World 1|/tmp/out|Arnis World 1|0' 'export-io dispatches directory export'
assert_output_contains "${output}" 'EXPORT_FILE:Arnis Pack.mcworld|/tmp/out|Arnis Pack.mcworld' 'export-io dispatches mcworld export'
assert_output_contains "${output}" '[OK] Exported world directory to: /tmp/out/Arnis World 1' 'export-io success log for directory'
assert_output_contains "${output}" '[OK] Exported .mcworld package to: /tmp/out/Arnis Pack.mcworld' 'export-io success log for mcworld'

trap - ERR
exit_code=0
output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-io.sh"
  WORLD_TYPES=(dir mcworld)
  WORLD_NAMES=("Same" "Same.mcworld")
  resolve_named_world_index Same
' 2>&1)" || exit_code=$?
trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
[ "${exit_code}" -eq 1 ] || die "export-io ambiguous name: expected exit 1, got ${exit_code}"
assert_output_contains "${output}" "World name 'Same' is ambiguous" 'export-io ambiguous world name message'

trap - ERR
exit_code=0
output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-io.sh"
  WORLD_TYPES=(zip)
  WORLD_NAMES=("bad")
  export_entry_by_index 0 /tmp/out ask
' 2>&1)" || exit_code=$?
trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
[ "${exit_code}" -eq 1 ] || die "export-io unsupported type: expected exit 1, got ${exit_code}"
assert_output_contains "${output}" "Unsupported world type 'zip'" 'export-io unsupported type message'

# x11-stack.sh: socket mapping, config rendering, and status output
x11_state_dir="$(mktemp -d)"
output="$(ARNIS_LOG_COLOR=never ARNIS_UNIT_ROOT="${REPO_ROOT}" ARNIS_X11_STATE_DIR="${x11_state_dir}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/x11-stack.sh"
  HOST_DISPLAY_ID=":99.0"
  VNC_PORT=5900
  VNC_BIND="127.0.0.1"
  VNC_PASSWORD=""
  HEADLESS_WIDTH=1920
  HEADLESS_HEIGHT=1080
  HEADLESS_DEPTH=24
  HEADLESS_FULLSCREEN=1
  HEADLESS_NO_TOOLBAR=1
  HEADLESS_WAIT_SECONDS=1
  STATE_DIR="${ARNIS_X11_STATE_DIR}"
  FLUXBOX_APPS_FILE="${STATE_DIR}/home/.fluxbox/apps"
  XVFB_LOG="${STATE_DIR}/xvfb.log"
  FLUXBOX_LOG="${STATE_DIR}/fluxbox.log"
  X11VNC_LOG="${STATE_DIR}/x11vnc.log"
  X11VNC_PASSWD_FILE="${STATE_DIR}/x11vnc.passwd"
  XVFB_PID_FILE="${STATE_DIR}/xvfb.pid"
  FLUXBOX_PID_FILE="${STATE_DIR}/fluxbox.pid"
  X11VNC_PID_FILE="${STATE_DIR}/x11vnc.pid"
  host_stack_running() { return 1; }
  setup_fluxbox_config
  printf "SOCKET=%s\n" "$(display_socket_path)"
  printf "APPS=%s\n" "$(cat "${FLUXBOX_APPS_FILE}")"
  print_host_status
' 2>&1)"
assert_output_contains "${output}" 'SOCKET=/tmp/.X11-unix/X99' 'x11-stack display_socket_path strips suffix'
assert_output_contains "${output}" '[Fullscreen] {yes}' 'x11-stack fullscreen config written'
assert_output_contains "${output}" '[WARN] Host headless display is not running.' 'x11-stack status warn when down'
assert_output_contains "${output}" '[NOTE] VNC endpoint: 127.0.0.1:5900' 'x11-stack status VNC endpoint'
assert_output_contains "${output}" '[NOTE] Fluxbox toolbar: hidden' 'x11-stack toolbar state'

output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" ARNIS_X11_STATE_DIR="${x11_state_dir}" bash -c '
  source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
  source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/x11-stack.sh"
  HEADLESS_FULLSCREEN=0
  STATE_DIR="${ARNIS_X11_STATE_DIR}/plain"
  FLUXBOX_APPS_FILE="${STATE_DIR}/home/.fluxbox/apps"
  setup_fluxbox_config
  if [ -s "${FLUXBOX_APPS_FILE}" ]; then
    echo not-empty
  else
    echo empty
  fi
')"
assert_output_contains "${output}" 'empty' 'x11-stack non-fullscreen config stays empty'

rm -rf "${x11_state_dir}"

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
