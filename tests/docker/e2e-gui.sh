#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"

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

count_generated_worlds() {
  run_compose run --rm --entrypoint sh arnis -c '
    set -eu
    base="$1"
    mkdir -p "$base"
    count=0
    for d in "$base"/Arnis\ World\ *; do
      if [ -d "$d" ]; then
        count=$((count + 1))
      fi
    done
    printf "%s\n" "$count"
  ' sh "${GEN_OUTPUT_DIR}"
}

verify_latest_world_artifacts() {
  run_compose run --rm --entrypoint sh arnis -c '
    set -eu
    base="$1"

    latest=""
    for d in "$base"/Arnis\ World\ *; do
      if [ -d "$d" ]; then
        latest="$d"
      fi
    done

    [ -n "$latest" ]
    [ -f "$latest/level.dat" ]
    [ -d "$latest/region" ]
    ls "$latest"/region/*.mca >/dev/null 2>&1
  ' sh "${GEN_OUTPUT_DIR}"
}

run_generation_with_retry() {
  local attempt=1
  local use_file_input=0

  if run_compose run --rm --entrypoint sh arnis -c '
    set -eu
    file="$1"
    [ -f "$file" ]
    [ -s "$file" ]
  ' sh "${GEN_INPUT_JSON}" >/dev/null 2>&1; then
    use_file_input=1
  fi

  while [ "${attempt}" -le "${GEN_RETRIES}" ]; do
    if [ "${use_file_input}" -eq 1 ]; then
      if "${REPO_ROOT}/scripts/docker/run.sh" arnis \
        --output-dir "${GEN_OUTPUT_DIR}" \
        --bbox "${GEN_BBOX}" \
        --file "${GEN_INPUT_JSON}" \
        --interior=false \
        --roof=false \
        --land-cover=false \
        --timeout 30
      then
        return 0
      fi
    elif "${REPO_ROOT}/scripts/docker/run.sh" arnis \
      --output-dir "${GEN_OUTPUT_DIR}" \
      --bbox "${GEN_BBOX}" \
      --save-json-file "${GEN_INPUT_JSON}" \
      --interior=false \
      --roof=false \
      --land-cover=false \
      --timeout 30
    then
      return 0
    fi

    if [ "${attempt}" -ge "${GEN_RETRIES}" ]; then
      break
    fi

    if [ "${use_file_input}" -eq 1 ]; then
      log_warn "GUI E2E (file input) generation attempt ${attempt}/${GEN_RETRIES} failed, retrying in ${GEN_RETRY_DELAY}s..."
    else
      log_warn "GUI E2E (network fallback) generation attempt ${attempt}/${GEN_RETRIES} failed, retrying in ${GEN_RETRY_DELAY}s..."
    fi
    sleep "${GEN_RETRY_DELAY}"
    attempt=$((attempt + 1))
  done

  return 1
}

cleanup() {
  run_compose stop arnis-gui-headless >/dev/null 2>&1 || true
  run_compose rm -fsv arnis-gui-headless >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

log_info 'Running Docker E2E GUI checks...'

require_image "${CLI_IMAGE}"
require_image "${HEADLESS_IMAGE}"

run_compose up -d arnis-gui-headless >/dev/null
wait_for_container_up
vnc_status="$(wait_for_vnc_ready)"
assert_output_contains "${vnc_status}" "client_count:" "initial VNC readiness"

# While GUI stack is running, generate a world via CLI path and verify artifacts.
before_count="$(count_generated_worlds)"
run_generation_with_retry
after_count="$(count_generated_worlds)"
if [ "${after_count}" -le "${before_count}" ]; then
  die "Expected world count in ${GEN_OUTPUT_DIR} to increase while GUI is running (before=${before_count}, after=${after_count})"
fi
verify_latest_world_artifacts

# Restart regression guard for GUI stack.
run_compose stop arnis-gui-headless >/dev/null
run_compose up -d arnis-gui-headless >/dev/null
wait_for_container_up
vnc_status="$(wait_for_vnc_ready)"
assert_output_contains "${vnc_status}" "client_count:" "VNC readiness after restart"

log_success 'Docker E2E GUI checks passed.'
