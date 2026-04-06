#!/usr/bin/env bash

[ "${ARNIS_DOCKER_DISPLAY_LOADED:-0}" = "1" ] && return 0
ARNIS_DOCKER_DISPLAY_LOADED=1

detect_display_id() {
  printf '%s\n' "${ARNIS_GUI_DISPLAY:-${DISPLAY:-:0}}"
}

detect_display_socket() {
  local display_id socket_id
  display_id="$(detect_display_id)"

  case "${display_id}" in
    :*)
      socket_id="${display_id#:}"
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