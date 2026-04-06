#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_SH="${SCRIPT_DIR}/../shared/common.sh"

if [ ! -f "${COMMON_SH}" ]; then
  COMMON_SH="/usr/local/shared/common.sh"
fi

if [ -f "${COMMON_SH}" ]; then
  # shellcheck disable=SC1091
  source "${COMMON_SH}"
fi

DISPLAY_ID="${DISPLAY:-:99}"
HEADLESS_WIDTH="${ARNIS_HEADLESS_WIDTH:-1920}"
HEADLESS_HEIGHT="${ARNIS_HEADLESS_HEIGHT:-1080}"
HEADLESS_DEPTH="${ARNIS_HEADLESS_DEPTH:-24}"
HEADLESS_FULLSCREEN="${ARNIS_HEADLESS_FULLSCREEN:-1}"
HEADLESS_NO_TOOLBAR="${ARNIS_HEADLESS_NO_TOOLBAR:-1}"
VNC_PORT="${ARNIS_GUI_VNC_PORT:-5900}"
VNC_BIND="${ARNIS_GUI_VNC_BIND:-127.0.0.1}"
VNC_PASSWORD="${ARNIS_GUI_VNC_PASSWORD:-}"
VNC_RFB_VERSION="${ARNIS_GUI_VNC_RFB_VERSION:-3.3}"
HEADLESS_WAIT_SECONDS="${ARNIS_HEADLESS_START_WAIT:-20}"
STATE_DIR="${ARNIS_HEADLESS_STATE_DIR:-/tmp/arnis-headless-gui}"
HOME_DIR="${STATE_DIR}/home"
XVFB_LOG="${STATE_DIR}/xvfb.log"
FLUXBOX_LOG="${STATE_DIR}/fluxbox.log"
X11VNC_LOG="${STATE_DIR}/x11vnc.log"
X11VNC_PASSWD_FILE="${STATE_DIR}/x11vnc.passwd"
FLUXBOX_APPS_FILE="${HOME_DIR}/.fluxbox/apps"

mkdir -p "${STATE_DIR}" "${HOME_DIR}/.fluxbox"
: > "${HOME_DIR}/.fluxbox/init"

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

cleanup() {
  jobs -pr | xargs -r kill 2>/dev/null || true
  wait || true
}

trap cleanup EXIT INT TERM

# Remove stale Xvfb lock file from a previous container run (e.g. after docker stop).
# Without this, Xvfb refuses to start and x11vnc subsequently fails.
_display_num="${DISPLAY_ID#:}"
_display_num="${_display_num%%.*}"
rm -f "/tmp/.X${_display_num}-lock" "/tmp/.X11-unix/X${_display_num}"

Xvfb "${DISPLAY_ID}" -screen 0 "${HEADLESS_WIDTH}x${HEADLESS_HEIGHT}x${HEADLESS_DEPTH}" -ac -nolisten tcp -extension MIT-SHM < /dev/null >"${XVFB_LOG}" 2>&1 &

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if DISPLAY="${DISPLAY_ID}" xdpyinfo >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

FLUXBOX_ARGS=(-rc "${HOME_DIR}/.fluxbox/init")
if [ "${HEADLESS_NO_TOOLBAR}" = "1" ]; then
  FLUXBOX_ARGS+=(-no-toolbar)
fi

DISPLAY="${DISPLAY_ID}" HOME="${HOME_DIR}" fluxbox "${FLUXBOX_ARGS[@]}" < /dev/null >"${FLUXBOX_LOG}" 2>&1 &
X11VNC_ARGS=(
  -display "${DISPLAY_ID}"
  -bg
  -o "${X11VNC_LOG}"
  -forever
  -shared
  -noshm
  -noxrecord
  -noxfixes
  -noxdamage
  -rfbversion "${VNC_RFB_VERSION}"
  -listen "${VNC_BIND}"
  -rfbport "${VNC_PORT}"
)

if [ -n "${VNC_PASSWORD}" ]; then
  x11vnc -storepasswd "${VNC_PASSWORD}" "${X11VNC_PASSWD_FILE}" >/dev/null
  X11VNC_ARGS+=(-rfbauth "${X11VNC_PASSWD_FILE}")
else
  X11VNC_ARGS+=(-nopw)
fi

DISPLAY="${DISPLAY_ID}" x11vnc "${X11VNC_ARGS[@]}"

wait_for_vnc() {
  local attempt=0
  local connect_host="${VNC_BIND}"

  case "${connect_host}" in
    0.0.0.0|::|'')
      connect_host="127.0.0.1"
      ;;
  esac

  while [ "${attempt}" -lt "${HEADLESS_WAIT_SECONDS}" ]; do
    if x11vnc -display "${DISPLAY_ID}" -query client_count >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  return 1
}

if ! wait_for_vnc; then
  tail -n 50 "${X11VNC_LOG}" >&2 || true
  exit 1
fi

exec /usr/local/bin/arnis
