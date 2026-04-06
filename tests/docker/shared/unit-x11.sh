#!/usr/bin/env bash

[ "${ARNIS_TEST_UNIT_X11_LOADED:-0}" = "1" ] && return 0
ARNIS_TEST_UNIT_X11_LOADED=1

run_unit_x11_tests() {
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
}