#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"
# shellcheck disable=SC1091
source "${TEST_DIR}/shared/unit-helpers.sh"
# shellcheck disable=SC1091
source "${TEST_DIR}/shared/unit-shared-core.sh"
# shellcheck disable=SC1091
source "${TEST_DIR}/shared/unit-entrypoints.sh"
# shellcheck disable=SC1091
source "${TEST_DIR}/shared/unit-export.sh"
# shellcheck disable=SC1091
source "${TEST_DIR}/shared/unit-x11.sh"

log_info 'Running unit tests for shared scripts and entrypoint logic...'
setup_mock_docker
trap cleanup_unit_artifacts EXIT

run_unit_shared_core_tests
run_unit_entrypoint_tests
run_unit_export_tests
run_unit_x11_tests

log_success 'Unit tests passed.'
