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
VNC_PORT="${ARNIS_GUI_VNC_PORT:-5900}"
VNC_PASSWORD="${ARNIS_GUI_VNC_PASSWORD:-}"
STATE_DIR="${ARNIS_HEADLESS_STATE_DIR:-/tmp/arnis-headless-gui}"
HOME_DIR="${STATE_DIR}/home"
XVFB_LOG="${STATE_DIR}/xvfb.log"
FLUXBOX_LOG="${STATE_DIR}/fluxbox.log"
X11VNC_LOG="${STATE_DIR}/x11vnc.log"
X11VNC_PASSWD_FILE="${STATE_DIR}/x11vnc.passwd"

mkdir -p "${STATE_DIR}" "${HOME_DIR}/.fluxbox"
: > "${HOME_DIR}/.fluxbox/init"

cleanup() {
  jobs -pr | xargs -r kill 2>/dev/null || true
  wait || true
}

trap cleanup EXIT INT TERM

Xvfb "${DISPLAY_ID}" -screen 0 "${HEADLESS_WIDTH}x${HEADLESS_HEIGHT}x${HEADLESS_DEPTH}" -ac -nolisten tcp -extension MIT-SHM < /dev/null >"${XVFB_LOG}" 2>&1 &

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if DISPLAY="${DISPLAY_ID}" xdpyinfo >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

DISPLAY="${DISPLAY_ID}" HOME="${HOME_DIR}" fluxbox -rc "${HOME_DIR}/.fluxbox/init" < /dev/null >"${FLUXBOX_LOG}" 2>&1 &
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
  -rfbversion 3.3
  -rfbport "${VNC_PORT}"
)

if [ -n "${VNC_PASSWORD}" ]; then
  x11vnc -storepasswd "${VNC_PASSWORD}" "${X11VNC_PASSWD_FILE}" >/dev/null
  X11VNC_ARGS+=(-rfbauth "${X11VNC_PASSWD_FILE}")
else
  X11VNC_ARGS+=(-nopw)
fi

DISPLAY="${DISPLAY_ID}" x11vnc "${X11VNC_ARGS[@]}"

exec /usr/local/bin/arnis
