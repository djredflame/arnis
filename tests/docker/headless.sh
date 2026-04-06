#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"

log_info 'Running headless GUI Docker workflow checks...'

preflight_teardown

require_image "${HEADLESS_IMAGE}"

cleanup() {
  run_compose stop arnis-gui-headless >/dev/null 2>&1 || true
  run_compose rm -fsv arnis-gui-headless >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

run_compose up -d arnis-gui-headless >/dev/null
sleep "${HEADLESS_WAIT_SECONDS}"

if ! run_compose exec -T arnis-gui-headless sh -lc 'echo ready' >/dev/null 2>&1; then
  run_compose ps arnis-gui-headless >&2 || true
  run_compose logs --tail 120 arnis-gui-headless >&2 || true
  die 'arnis-gui-headless did not become reachable via docker compose exec'
fi

output="$(run_compose logs --tail 100 arnis-gui-headless 2>&1 || true)"
assert_output_contains "${output}" "PORT=" "arnis-gui-headless startup logs"

cleanup
trap - EXIT INT TERM

log_success 'Headless GUI Docker workflow checks passed.'
