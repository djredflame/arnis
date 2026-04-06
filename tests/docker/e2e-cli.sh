#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"

GEN_OUTPUT_DIR="${ARNIS_E2E_CLI_OUTPUT_DIR:-/data/e2e-cli-worlds}"
GEN_BBOX="${ARNIS_E2E_CLI_BBOX:-54.627053,9.927928,54.627553,9.928428}"
GEN_RETRIES="${ARNIS_E2E_CLI_GENERATION_RETRIES:-2}"
GEN_RETRY_DELAY="${ARNIS_E2E_CLI_GENERATION_RETRY_DELAY:-5}"
GEN_OSM_JSON="${ARNIS_E2E_CLI_OSM_JSON:-/data/e2e-cli-worlds/e2e-overpass.json}"

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
    [ -f "$latest/icon.png" ]
    [ -d "$latest/region" ]
    ls "$latest"/region/*.mca >/dev/null 2>&1
  ' sh "${GEN_OUTPUT_DIR}"
}

verify_file_artifact() {
  run_compose run --rm --entrypoint sh arnis -c '
    set -eu
    file="$1"
    [ -f "$file" ]
    [ -s "$file" ]
  ' sh "${GEN_OSM_JSON}"
}

run_generation_with_retry() {
  local attempt=1

  while [ "${attempt}" -le "${GEN_RETRIES}" ]; do
    if "${REPO_ROOT}/scripts/docker/run.sh" arnis \
      --output-dir "${GEN_OUTPUT_DIR}" \
      --bbox "${GEN_BBOX}" \
      --save-json-file "${GEN_OSM_JSON}" \
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

    log_warn "CLI E2E generation attempt ${attempt}/${GEN_RETRIES} failed, retrying in ${GEN_RETRY_DELAY}s..."
    sleep "${GEN_RETRY_DELAY}"
    attempt=$((attempt + 1))
  done

  return 1
}

log_info 'Running Docker E2E CLI checks...'

require_image "${CLI_IMAGE}"

output="$(${REPO_ROOT}/scripts/docker/run.sh --version)"
assert_output_contains "${output}" "arnis " "CLI E2E version output"

before_count="$(count_generated_worlds)"
run_generation_with_retry
verify_file_artifact

"${REPO_ROOT}/scripts/docker/run.sh" arnis \
  --output-dir "${GEN_OUTPUT_DIR}" \
  --bbox "${GEN_BBOX}" \
  --file "${GEN_OSM_JSON}" \
  --interior=false \
  --roof=false \
  --land-cover=false \
  --timeout 30

after_count="$(count_generated_worlds)"
if [ $((after_count - before_count)) -lt 2 ]; then
  die "Expected at least two new worlds in ${GEN_OUTPUT_DIR} (before=${before_count}, after=${after_count})"
fi

verify_latest_world_artifacts

log_success 'Docker E2E CLI checks passed.'
