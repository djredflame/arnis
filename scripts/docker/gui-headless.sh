#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"

X11_HOST_HELPER="${SCRIPT_DIR}/x11-host.sh"
VNC_PORT="${ARNIS_GUI_VNC_PORT:-5900}"
VNC_BIND="${ARNIS_GUI_VNC_BIND:-127.0.0.1}"
VNC_PASSWORD="${ARNIS_GUI_VNC_PASSWORD:-}"
HEADLESS_WIDTH="${ARNIS_HEADLESS_WIDTH:-1920}"
HEADLESS_HEIGHT="${ARNIS_HEADLESS_HEIGHT:-1080}"
HEADLESS_DEPTH="${ARNIS_HEADLESS_DEPTH:-24}"
HEADLESS_FULLSCREEN="${ARNIS_HEADLESS_FULLSCREEN:-1}"
HEADLESS_NO_TOOLBAR="${ARNIS_HEADLESS_NO_TOOLBAR:-1}"
HEADLESS_WAIT_SECONDS="${ARNIS_HEADLESS_START_WAIT:-20}"

print_help() {
  log_plain 'Notes:'
  log_plain '  This helper is optional and only intended for headless Linux hosts.'
  log_plain '  It runs Xvfb/x11vnc on the host and attaches the Dockerized arnis-gui service to that host display.'
  log_plain '  Native Linux/X11 hosts can use ./scripts/docker/up.sh arnis-gui directly.'
  log_plain '  Configure bind address, port, password, and display size via .env.docker.'
  log_plain "  Headless display size defaults to ${HEADLESS_WIDTH}x${HEADLESS_HEIGHT}x${HEADLESS_DEPTH}."
  if [ "${HEADLESS_FULLSCREEN}" = "1" ]; then
    log_plain '  Arnis fullscreen is enabled by default for the headless desktop.'
  fi
  log_plain
  print_examples_header
  log_plain '  ./scripts/docker/gui-headless.sh up'
  log_plain '  ./scripts/docker/gui-headless.sh logs'
  log_plain '  ./scripts/docker/gui-headless.sh down'
}

handle_compose_help "${1:-}" '{up|down|restart|logs|status}' 'Runs arnis-gui against a host-managed headless X11/VNC display.' false print_help

gui_container_running() {
  [ -n "$(run_compose ps --status running --services arnis-gui 2>/dev/null || true)" ]
}

case "${1:-}" in
  up)
    "${X11_HOST_HELPER}" up
    run_compose_with_env ARNIS_GUI_DISPLAY "${ARNIS_HEADLESS_DISPLAY:-:99}" up -d arnis-gui
    if ! gui_container_running; then
      run_compose logs --tail 50 arnis-gui >&2 || true
      die "arnis-gui did not become ready within ${HEADLESS_WAIT_SECONDS}s."
    fi
    log_success 'Headless GUI is ready.'
    log_note "VNC endpoint: ${VNC_BIND}:${VNC_PORT}"
    log_note "Headless display: ${HEADLESS_WIDTH}x${HEADLESS_HEIGHT}x${HEADLESS_DEPTH}"
    if [ "${HEADLESS_FULLSCREEN}" = "1" ]; then
      log_note 'Arnis fullscreen: enabled'
    else
      log_note 'Arnis fullscreen: disabled'
    fi
    if [ "${HEADLESS_NO_TOOLBAR}" = "1" ]; then
      log_note 'Fluxbox toolbar: hidden'
    else
      log_note 'Fluxbox toolbar: visible'
    fi
    if [ -n "${VNC_PASSWORD}" ]; then
      log_note "VNC authentication: enabled"
    else
      log_note "VNC authentication: disabled"
    fi
    ;;
  down)
    run_compose stop arnis-gui >/dev/null 2>&1 || true
    run_compose rm -fsv arnis-gui >/dev/null 2>&1 || true
    "${X11_HOST_HELPER}" down
    ;;
  restart)
    "$0" down
    "$0" up
    ;;
  logs)
    "${X11_HOST_HELPER}" logs
    log_plain
    run_compose logs -f arnis-gui
    ;;
  status)
    "${X11_HOST_HELPER}" status
    if ! gui_container_running; then
      log_warn 'Headless GUI is not running.'
      log_note 'Start it with: ./scripts/docker/gui-headless.sh up'
      exit 0
    fi
    log_plain
    run_compose ps arnis-gui
    ;;
  *)
    print_help >&2
    exit 1
    ;;
esac
