#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"
# shellcheck disable=SC1091
source "${TEST_DIR}/shared/e2e-worlds.sh"

GEN_OUTPUT_DIR="${ARNIS_E2E_CLI_OUTPUT_DIR:-/data/e2e-cli-worlds}"
GEN_BBOX="${ARNIS_E2E_CLI_BBOX:-54.627053,9.927928,54.627553,9.928428}"
GEN_RETRIES="${ARNIS_E2E_CLI_GENERATION_RETRIES:-2}"
GEN_RETRY_DELAY="${ARNIS_E2E_CLI_GENERATION_RETRY_DELAY:-5}"
GEN_OSM_JSON="${ARNIS_E2E_CLI_OSM_JSON:-/data/e2e-cli-worlds/e2e-overpass.json}"

log_info 'Running Docker E2E CLI checks...'

require_image "${CLI_IMAGE}"

output="$(${REPO_ROOT}/scripts/docker/run.sh --version)"
assert_output_contains "${output}" "arnis " "CLI E2E version output"

before_count="$(e2e_count_generated_worlds "${GEN_OUTPUT_DIR}")"
e2e_run_generation_with_retry "${GEN_OUTPUT_DIR}" "${GEN_BBOX}" "${GEN_OSM_JSON}" "${GEN_RETRIES}" "${GEN_RETRY_DELAY}" 'CLI E2E'
e2e_verify_file_artifact "${GEN_OSM_JSON}"

"${REPO_ROOT}/scripts/docker/run.sh" arnis \
  --output-dir "${GEN_OUTPUT_DIR}" \
  --bbox "${GEN_BBOX}" \
  --file "${GEN_OSM_JSON}" \
  --interior=false \
  --roof=false \
  --land-cover=false \
  --timeout 30

after_count="$(e2e_count_generated_worlds "${GEN_OUTPUT_DIR}")"
if [ $((after_count - before_count)) -lt 2 ]; then
  die "Expected at least two new worlds in ${GEN_OUTPUT_DIR} (before=${before_count}, after=${after_count})"
fi

e2e_verify_latest_world_artifacts "${GEN_OUTPUT_DIR}" 1

log_success 'Docker E2E CLI checks passed.'
