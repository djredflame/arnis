#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shared/x11-stack.sh"

HOST_DISPLAY_ID="${ARNIS_HEADLESS_DISPLAY:-:99}"
VNC_PORT="${ARNIS_GUI_VNC_PORT:-5900}"
VNC_BIND="${ARNIS_GUI_VNC_BIND:-127.0.0.1}"
VNC_PASSWORD="${ARNIS_GUI_VNC_PASSWORD:-}"
HEADLESS_WIDTH="${ARNIS_HEADLESS_WIDTH:-1920}"
HEADLESS_HEIGHT="${ARNIS_HEADLESS_HEIGHT:-1080}"
HEADLESS_DEPTH="${ARNIS_HEADLESS_DEPTH:-24}"
HEADLESS_FULLSCREEN="${ARNIS_HEADLESS_FULLSCREEN:-1}"
HEADLESS_NO_TOOLBAR="${ARNIS_HEADLESS_NO_TOOLBAR:-1}"
HEADLESS_WAIT_SECONDS="${ARNIS_HEADLESS_START_WAIT:-20}"
STATE_DIR="${ARNIS_HEADLESS_HOST_STATE_DIR:-/tmp/arnis-headless-host}"
FLUXBOX_APPS_FILE="${STATE_DIR}/home/.fluxbox/apps"
XVFB_LOG="${STATE_DIR}/xvfb.log"
FLUXBOX_LOG="${STATE_DIR}/fluxbox.log"
X11VNC_LOG="${STATE_DIR}/x11vnc.log"
X11VNC_PASSWD_FILE="${STATE_DIR}/x11vnc.passwd"
XVFB_PID_FILE="${STATE_DIR}/xvfb.pid"
FLUXBOX_PID_FILE="${STATE_DIR}/fluxbox.pid"
X11VNC_PID_FILE="${STATE_DIR}/x11vnc.pid"

case "${1:-}" in
  up)
    ensure_host_dependencies
    if host_stack_running; then
      print_host_status
      exit 0
    fi
    start_host_stack
    print_host_status
    ;;
  down)
    stop_host_stack
    ;;
  status)
    print_host_status
    ;;
  logs)
    tail -n 50 "${XVFB_LOG}" "${FLUXBOX_LOG}" "${X11VNC_LOG}" 2>/dev/null || true
    ;;
  *)
    die "Usage: $(basename "$0") {up|down|status|logs}"
    ;;
esac
