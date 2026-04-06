#!/usr/bin/env bash
# Sourced by x11-host.sh. Requires: config vars (HOST_DISPLAY_ID, VNC_*,
# HEADLESS_*, STATE_DIR, *_PID_FILE, *_LOG) and shared logger/die functions.

[ "${X11_STACK_LOADED:-0}" = "1" ] && return 0
X11_STACK_LOADED=1

display_socket_path() {
  local socket_id="${HOST_DISPLAY_ID#:}"
  socket_id="${socket_id%%.*}"
  log_plain "/tmp/.X11-unix/X${socket_id}"
}

ensure_host_dependencies() {
  command -v Xvfb >/dev/null 2>&1 || die 'Missing host dependency: Xvfb'
  command -v fluxbox >/dev/null 2>&1 || die 'Missing host dependency: fluxbox'
  command -v x11vnc >/dev/null 2>&1 || die 'Missing host dependency: x11vnc'
  command -v xdpyinfo >/dev/null 2>&1 || die 'Missing host dependency: xdpyinfo'
  command -v setsid >/dev/null 2>&1 || die 'Missing host dependency: setsid'
}

pid_is_running() {
  local pid_file="$1"

  [ -f "${pid_file}" ] || return 1
  kill -0 "$(cat "${pid_file}")" >/dev/null 2>&1
}

host_stack_running() {
  pid_is_running "${XVFB_PID_FILE}" &&
  pid_is_running "${FLUXBOX_PID_FILE}" &&
  pid_is_running "${X11VNC_PID_FILE}"
}

wait_for_host_display() {
  local attempt=0

  while [ "${attempt}" -lt "${HEADLESS_WAIT_SECONDS}" ]; do
    if DISPLAY="${HOST_DISPLAY_ID}" xdpyinfo >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  return 1
}

wait_for_host_vnc() {
  local attempt=0
  local connect_host="${VNC_BIND}"

  case "${connect_host}" in
    0.0.0.0|::|'')
      connect_host="127.0.0.1"
      ;;
  esac

  while [ "${attempt}" -lt "${HEADLESS_WAIT_SECONDS}" ]; do
    if timeout 2 bash -lc '
      exec 3<>/dev/tcp/'"${connect_host}"'/'"${VNC_PORT}"'
      IFS= read -r -N 12 banner <&3 || exit 1
      case "${banner}" in
        RFB\ 003.*) exit 0 ;;
        *) exit 1 ;;
      esac
    ' >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  return 1
}

start_detached_command() {
  local pid_file="$1"
  local log_file="$2"
  shift 2

  nohup setsid "$@" < /dev/null >"${log_file}" 2>&1 &
  echo "$!" > "${pid_file}"
}

setup_fluxbox_config() {
  mkdir -p "${STATE_DIR}" "${STATE_DIR}/home/.fluxbox"
  : > "${STATE_DIR}/home/.fluxbox/init"

  if [ "${HEADLESS_FULLSCREEN}" = "1" ]; then
    cat > "${FLUXBOX_APPS_FILE}" <<'EOF'
[app] (Class=Arnis)
  [IgnoreSizeHints] {yes}
  [Position] (TopLeft) {0 0}
  [Dimensions] {100% 100%}
  [Maximized] {yes}
  [Fullscreen] {yes}
  [Deco] {NONE}
[end]
EOF
  else
    : > "${FLUXBOX_APPS_FILE}"
  fi
}

start_host_stack() {
  setup_fluxbox_config

  start_detached_command \
    "${XVFB_PID_FILE}" \
    "${XVFB_LOG}" \
    Xvfb "${HOST_DISPLAY_ID}" -screen 0 "${HEADLESS_WIDTH}x${HEADLESS_HEIGHT}x${HEADLESS_DEPTH}" -ac -nolisten tcp -extension MIT-SHM

  if ! wait_for_host_display; then
    tail -n 50 "${XVFB_LOG}" >&2 || true
    die "Host Xvfb display ${HOST_DISPLAY_ID} did not become ready within ${HEADLESS_WAIT_SECONDS}s."
  fi

  local fluxbox_args=(-rc "${STATE_DIR}/home/.fluxbox/init")
  if [ "${HEADLESS_NO_TOOLBAR}" = "1" ]; then
    fluxbox_args+=(-no-toolbar)
  fi

  start_detached_command \
    "${FLUXBOX_PID_FILE}" \
    "${FLUXBOX_LOG}" \
    env DISPLAY="${HOST_DISPLAY_ID}" HOME="${STATE_DIR}/home" fluxbox "${fluxbox_args[@]}"

  if [ -n "${VNC_PASSWORD}" ]; then
    x11vnc -storepasswd "${VNC_PASSWORD}" "${X11VNC_PASSWD_FILE}" >/dev/null
  fi

  local x11vnc_args=(
    -display "${HOST_DISPLAY_ID}"
    -bg
    -o "${X11VNC_LOG}"
    -forever
    -shared
    -noshm
    -noxrecord
    -noxfixes
    -noxdamage
    -rfbversion 3.3
    -listen "${VNC_BIND}"
    -rfbport "${VNC_PORT}"
  )

  if [ -n "${VNC_PASSWORD}" ]; then
    x11vnc_args+=(-rfbauth "${X11VNC_PASSWD_FILE}")
  else
    x11vnc_args+=(-nopw)
  fi

  DISPLAY="${HOST_DISPLAY_ID}" x11vnc "${x11vnc_args[@]}"

  pgrep -f "x11vnc .*${VNC_PORT}" | head -n 1 > "${X11VNC_PID_FILE}" || true

  if ! wait_for_host_vnc; then
    tail -n 50 "${X11VNC_LOG}" >&2 || true
    die "Host x11vnc did not become ready on ${VNC_BIND}:${VNC_PORT} within ${HEADLESS_WAIT_SECONDS}s."
  fi
}

stop_pid_file() {
  local pid_file="$1"

  [ -f "${pid_file}" ] || return 0

  local pid
  pid="$(cat "${pid_file}")"

  kill "${pid}" >/dev/null 2>&1 || true
  wait "${pid}" >/dev/null 2>&1 || true
  rm -f "${pid_file}"
}

stop_host_stack() {
  stop_pid_file "${X11VNC_PID_FILE}"
  stop_pid_file "${FLUXBOX_PID_FILE}"
  stop_pid_file "${XVFB_PID_FILE}"
}

print_host_status() {
  if host_stack_running; then
    log_success "Host headless display is running on ${HOST_DISPLAY_ID}."
  else
    log_warn 'Host headless display is not running.'
  fi

  log_note "VNC endpoint: ${VNC_BIND}:${VNC_PORT}"
  log_note "Headless display: ${HEADLESS_WIDTH}x${HEADLESS_HEIGHT}x${HEADLESS_DEPTH}"
  log_note "X11 socket: $(display_socket_path)"

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
    log_note 'VNC authentication: enabled'
  else
    log_note 'VNC authentication: disabled'
  fi
}
