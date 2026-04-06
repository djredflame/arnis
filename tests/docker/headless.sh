#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"

log_info 'Running headless GUI Docker workflow checks...'

require_image "${HEADLESS_IMAGE}"

cleanup() {
  run_compose stop arnis-gui-headless >/dev/null 2>&1 || true
  run_compose rm -fsv arnis-gui-headless >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

run_compose up -d arnis-gui-headless >/dev/null
sleep "${HEADLESS_WAIT_SECONDS}"

container_id="$(run_compose ps -q arnis-gui-headless 2>/dev/null || true)"
[ -n "${container_id}" ] || die 'compose did not return a container id for arnis-gui-headless'

running_state="$(docker inspect -f '{{.State.Running}}' "${container_id}" 2>/dev/null || true)"
[ "${running_state}" = "true" ] || die 'arnis-gui-headless container is not in running state'

output="$(run_compose logs --tail 100 arnis-gui-headless 2>&1 || true)"
assert_output_contains "${output}" "PORT=" "arnis-gui-headless startup logs"

cleanup
trap - EXIT INT TERM

log_success 'Headless GUI Docker workflow checks passed.'
