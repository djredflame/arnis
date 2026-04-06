#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"
# shellcheck disable=SC1091
source "${TEST_DIR}/shared/e2e-worlds.sh"

VNC_HOST="${ARNIS_GUI_VNC_BIND:-127.0.0.1}"
VNC_PORT="${ARNIS_GUI_VNC_PORT:-5900}"
VNC_READY_WAIT_SECONDS="${ARNIS_E2E_GUI_VNC_READY_WAIT:-45}"
GEN_OUTPUT_DIR="${ARNIS_E2E_GUI_OUTPUT_DIR:-/data/e2e-gui-worlds}"
GEN_BBOX="${ARNIS_E2E_GUI_BBOX:-54.627053,9.927928,54.627553,9.928428}"
GEN_RETRIES="${ARNIS_E2E_GUI_GENERATION_RETRIES:-2}"
GEN_RETRY_DELAY="${ARNIS_E2E_GUI_GENERATION_RETRY_DELAY:-5}"
GEN_INPUT_JSON="${ARNIS_E2E_GUI_INPUT_JSON:-/data/e2e-cli-worlds/e2e-overpass.json}"

if [ "${VNC_HOST}" = "0.0.0.0" ] || [ "${VNC_HOST}" = "::" ] || [ -z "${VNC_HOST}" ]; then
  VNC_HOST="127.0.0.1"
fi

wait_for_container_up() {
  local attempts=0
  local max_attempts=20
  local output

  while [ "${attempts}" -lt "${max_attempts}" ]; do
    output="$(run_compose ps arnis-gui-headless 2>/dev/null || true)"
    case "${output}" in
      *"Up"*) return 0 ;;
    esac
    attempts=$((attempts + 1))
    sleep 1
  done

  run_compose ps arnis-gui-headless >&2 || true
  die "arnis-gui-headless did not reach Up state"
}

wait_for_vnc_ready() {
  local display_id="${ARNIS_HEADLESS_DISPLAY:-:99}"
  local attempt=0

  while [ "${attempt}" -lt "${VNC_READY_WAIT_SECONDS}" ]; do
    if output="$(run_compose exec -T arnis-gui-headless sh -lc 'x11vnc -display "'"${display_id}"'" -query client_count' 2>/dev/null)"; then
      case "${output}" in
        *"client_count:"*)
          printf '%s\n' "${output}"
          return 0
          ;;
      esac
    fi

    attempt=$((attempt + 1))
    sleep 1
  done

  run_compose logs --tail 120 arnis-gui-headless >&2 || true
  die "VNC readiness query timed out on ${VNC_HOST}:${VNC_PORT} after ${VNC_READY_WAIT_SECONDS}s"
}

cleanup() {
  run_compose stop arnis-gui-headless >/dev/null 2>&1 || true
  run_compose rm -fsv arnis-gui-headless >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

log_info 'Running Docker E2E GUI checks...'

preflight_teardown

require_image "${CLI_IMAGE}"
require_image "${HEADLESS_IMAGE}"

run_compose up -d arnis-gui-headless >/dev/null
wait_for_container_up
vnc_status="$(wait_for_vnc_ready)"
assert_output_contains "${vnc_status}" "client_count:" "initial VNC readiness"

# While GUI stack is running, generate a world via CLI path and verify artifacts.
before_count="$(e2e_count_generated_worlds "${GEN_OUTPUT_DIR}")"
e2e_run_generation_with_retry "${GEN_OUTPUT_DIR}" "${GEN_BBOX}" "${GEN_INPUT_JSON}" "${GEN_RETRIES}" "${GEN_RETRY_DELAY}" 'GUI E2E'
after_count="$(e2e_count_generated_worlds "${GEN_OUTPUT_DIR}")"
if [ "${after_count}" -le "${before_count}" ]; then
  die "Expected world count in ${GEN_OUTPUT_DIR} to increase while GUI is running (before=${before_count}, after=${after_count})"
fi
e2e_verify_latest_world_artifacts "${GEN_OUTPUT_DIR}" 0

# Restart regression guard for GUI stack.
run_compose stop arnis-gui-headless >/dev/null
run_compose up -d arnis-gui-headless >/dev/null
wait_for_container_up
vnc_status="$(wait_for_vnc_ready)"
assert_output_contains "${vnc_status}" "client_count:" "VNC readiness after restart"

log_success 'Docker E2E GUI checks passed.'
