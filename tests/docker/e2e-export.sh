#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${TEST_DIR}/lib.sh"
# shellcheck disable=SC1091
source "${TEST_DIR}/shared/e2e-worlds.sh"

GEN_OUTPUT_DIR="${ARNIS_E2E_EXPORT_OUTPUT_DIR:-/data/e2e-export-worlds}"
GEN_BBOX="${ARNIS_E2E_EXPORT_BBOX:-54.627053,9.927928,54.627553,9.928428}"
GEN_INPUT_JSON="${ARNIS_E2E_EXPORT_INPUT_JSON:-/data/e2e-cli-worlds/e2e-overpass.json}"
GEN_RETRIES="${ARNIS_E2E_EXPORT_GENERATION_RETRIES:-2}"
GEN_RETRY_DELAY="${ARNIS_E2E_EXPORT_GENERATION_RETRY_DELAY:-5}"
HOST_EXPORT_DIR="${ARNIS_E2E_EXPORT_HOST_DIR:-${REPO_ROOT}/.tmp/e2e-export-out}"

generate_world_if_missing() {
  if e2e_get_latest_world_name "${GEN_OUTPUT_DIR}" >/dev/null 2>&1; then
    return 0
  fi
  e2e_run_generation_with_retry "${GEN_OUTPUT_DIR}" "${GEN_BBOX}" "${GEN_INPUT_JSON}" "${GEN_RETRIES}" "${GEN_RETRY_DELAY}" 'E2E export setup'
}

verify_exported_world() {
  local world_name="$1"
  local out_dir="$2"

  [ -d "${out_dir}/${world_name}" ] || die "Expected exported world directory at ${out_dir}/${world_name}"
  [ -f "${out_dir}/${world_name}/level.dat" ] || die "Exported world missing level.dat"
  [ -d "${out_dir}/${world_name}/region" ] || die "Exported world missing region directory"
  ls "${out_dir}/${world_name}"/region/*.mca >/dev/null 2>&1 || die "Exported world missing .mca files"
}

assert_copy_created() {
  local world_name="$1"
  local out_dir="$2"
  local copy_dir="${out_dir}/${world_name} (copy)"

  [ -d "${copy_dir}" ] || die "Expected copy directory at ${copy_dir}"
  [ -f "${copy_dir}/level.dat" ] || die "Copy export missing level.dat"
}

log_info 'Running Docker E2E export checks...'

require_image "${CLI_IMAGE}"

generate_world_if_missing
world_name="$(e2e_get_latest_world_name "${GEN_OUTPUT_DIR}")"

list_output="$(${REPO_ROOT}/scripts/docker/export-world.sh --list 2>&1 || true)"
assert_output_contains "${list_output}" "Detected worlds:" "export-world --list output"
assert_output_contains "${list_output}" "${world_name}" "export-world --list contains generated world"

rm -rf "${HOST_EXPORT_DIR}"
mkdir -p "${HOST_EXPORT_DIR}"

"${REPO_ROOT}/scripts/docker/export-world.sh" "${world_name}" "${HOST_EXPORT_DIR}"
verify_exported_world "${world_name}" "${HOST_EXPORT_DIR}"

all_export_dir="${HOST_EXPORT_DIR}/all"
mkdir -p "${all_export_dir}"
"${REPO_ROOT}/scripts/docker/export-world.sh" --all "${all_export_dir}"
verify_exported_world "${world_name}" "${all_export_dir}"

conflict_export_dir="${HOST_EXPORT_DIR}/conflict"
mkdir -p "${conflict_export_dir}"
"${REPO_ROOT}/scripts/docker/export-world.sh" "${world_name}" "${conflict_export_dir}"
"${REPO_ROOT}/scripts/docker/export-world.sh" --on-conflict copy "${world_name}" "${conflict_export_dir}"
verify_exported_world "${world_name}" "${conflict_export_dir}"
assert_copy_created "${world_name}" "${conflict_export_dir}"

log_success 'Docker E2E export checks passed.'
