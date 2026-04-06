#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"

log_info 'Running runtime Docker workflow checks...'

preflight_teardown

require_image "${CLI_IMAGE}"

output="$(${REPO_ROOT}/scripts/docker/run.sh --version)"
assert_output_contains "${output}" "arnis " "run.sh --version"

output="$(${REPO_ROOT}/scripts/docker/run.sh arnis --version)"
assert_output_contains "${output}" "arnis " "run.sh arnis --version"

"${REPO_ROOT}/scripts/docker/ps.sh" --all >/dev/null

output="$(${REPO_ROOT}/scripts/docker/run.sh arnis-gui-headless 2>&1 || true)"
assert_output_contains "${output}" "Use ./scripts/docker/gui-headless.sh" "run.sh arnis-gui-headless guard"

log_success 'Runtime Docker workflow checks passed.'
