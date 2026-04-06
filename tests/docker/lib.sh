#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${TEST_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/shared/docker.sh"

CLI_IMAGE="${ARNIS_CLI_IMAGE:-arnis:local}"
HEADLESS_IMAGE="${ARNIS_HEADLESS_IMAGE:-arnis-gui-headless:local}"
HEADLESS_WAIT_SECONDS="${ARNIS_HEADLESS_START_WAIT:-5}"

require_file() {
  local path="$1"
  [ -f "${path}" ] || die "Missing required file: ${path}"
}

require_env_key() {
  local key="$1"
  grep -q "^${key}=" "${REPO_ROOT}/.env.docker.example" || die "Missing ${key} in .env.docker.example"
}

assert_output_contains() {
  local output="$1"
  local needle="$2"
  local context="$3"

  case "${output}" in
    *"${needle}"*) ;;
    *)
      die "${context} did not contain expected text: ${needle}"
      ;;
  esac
}

require_image() {
  local image="$1"
  docker image inspect "${image}" >/dev/null 2>&1 || die "Required image not found: ${image}. Build it first."
}
