#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"

log_info 'Running static Docker workflow checks...'

bash -n "${REPO_ROOT}"/scripts/shared/*.sh
bash -n "${REPO_ROOT}"/scripts/docker/*.sh
bash -n "${REPO_ROOT}"/scripts/docker/shared/*.sh

require_file "${REPO_ROOT}/.env.docker.example"
require_env_key "ARNIS_BUILD_NETWORK"
require_env_key "ARNIS_CLI_IMAGE"
require_env_key "ARNIS_TEST_IMAGE"
require_env_key "ARNIS_GUI_IMAGE"
require_env_key "ARNIS_HEADLESS_IMAGE"
require_env_key "ARNIS_LOG_COLOR"
require_env_key "ARNIS_RUN_BUILD_VALIDATION"
require_env_key "ARNIS_GUI_DISPLAY"
require_env_key "ARNIS_HEADLESS_DISPLAY"
require_env_key "ARNIS_HEADLESS_WIDTH"
require_env_key "ARNIS_HEADLESS_HEIGHT"
require_env_key "ARNIS_HEADLESS_DEPTH"
require_env_key "ARNIS_HEADLESS_FULLSCREEN"
require_env_key "ARNIS_HEADLESS_NO_TOOLBAR"
require_env_key "ARNIS_GUI_VNC_BIND"
require_env_key "ARNIS_GUI_VNC_PORT"
require_env_key "ARNIS_GUI_VNC_PASSWORD"
require_env_key "ARNIS_DISABLE_OS_COMPOSE_OVERRIDE"
require_env_key "ARNIS_WORLD_EXPORT_DIR"
require_env_key "ARNIS_DOCKER_COPY_IMAGE"

output="$(${REPO_ROOT}/scripts/docker/build.sh --help)"
assert_output_contains "${output}" ".env.docker.example" "build.sh --help"
assert_output_contains "${output}" "--with-tests" "build.sh --help"

output="$(${REPO_ROOT}/scripts/docker/up.sh --help)"
assert_output_contains "${output}" "arnis-gui-headless" "up.sh --help"

output="$(${REPO_ROOT}/scripts/docker/run.sh --help)"
assert_output_contains "${output}" ".env.docker.example" "run.sh --help"

output="$(${REPO_ROOT}/scripts/docker/logs.sh --help)"
assert_output_contains "${output}" "arnis-gui-headless" "logs.sh --help"

output="$(${REPO_ROOT}/scripts/docker/gui-headless.sh --help)"
assert_output_contains "${output}" "Headless display size defaults" "gui-headless.sh --help"

output="$(${REPO_ROOT}/scripts/docker/ps.sh --help)"
assert_output_contains "${output}" "Lists the services" "ps.sh --help"

output="$(${REPO_ROOT}/scripts/docker/export-world.sh --help)"
assert_output_contains "${output}" "Exports generated worlds" "export-world.sh --help"
assert_output_contains "${output}" "--list" "export-world.sh --help"

output="$(${REPO_ROOT}/scripts/docker/down.sh --help)"
assert_output_contains "${output}" "Stops services" "down.sh --help"

output="$(${REPO_ROOT}/scripts/docker/rm.sh --help)"
assert_output_contains "${output}" "Removes stopped service containers" "rm.sh --help"

output="$(${REPO_ROOT}/scripts/docker/up.sh invalid-service 2>&1 || true)"
assert_output_contains "${output}" "Unknown service: invalid-service" "up.sh invalid-service"

output="$(${REPO_ROOT}/scripts/docker/logs.sh invalid-service 2>&1 || true)"
assert_output_contains "${output}" "Unknown service: invalid-service" "logs.sh invalid-service"

output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
	source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
	false
' 2>&1 || true)"
assert_output_contains "${output}" "failed." "shared common error trap"
assert_output_contains "${output}" "Command: false" "shared common error trap"

run_compose config --quiet

log_success 'Static Docker workflow checks passed.'
