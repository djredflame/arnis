#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${TEST_DIR}/../.." && pwd)"

# Reuse the Docker wrapper helpers so tests and normal workflows stay aligned.
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

run_static_tests() {
  log_info 'Running static Docker workflow checks...'

  bash -n "${REPO_ROOT}"/scripts/shared/*.sh
  bash -n "${REPO_ROOT}"/scripts/docker/*.sh

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
  require_env_key "ARNIS_GUI_VNC_BIND"
  require_env_key "ARNIS_GUI_VNC_PORT"
  require_env_key "ARNIS_GUI_VNC_PASSWORD"

  local output

  output="$("${REPO_ROOT}/scripts/docker/build.sh" --help)"
  assert_output_contains "${output}" ".env.docker.example" "build.sh --help"
  assert_output_contains "${output}" "--with-tests" "build.sh --help"

  output="$("${REPO_ROOT}/scripts/docker/up.sh" --help)"
  assert_output_contains "${output}" "arnis-gui-headless" "up.sh --help"

  output="$("${REPO_ROOT}/scripts/docker/run.sh" --help)"
  assert_output_contains "${output}" ".env.docker.example" "run.sh --help"

  output="$("${REPO_ROOT}/scripts/docker/logs.sh" --help)"
  assert_output_contains "${output}" "arnis-gui-headless" "logs.sh --help"

  output="$("${REPO_ROOT}/scripts/docker/gui-headless.sh" --help)"
  assert_output_contains "${output}" "Headless display size defaults" "gui-headless.sh --help"

  output="$("${REPO_ROOT}/scripts/docker/ps.sh" --help)"
  assert_output_contains "${output}" "Lists the services" "ps.sh --help"

  output="$("${REPO_ROOT}/scripts/docker/down.sh" --help)"
  assert_output_contains "${output}" "Stops services" "down.sh --help"

  output="$("${REPO_ROOT}/scripts/docker/rm.sh" --help)"
  assert_output_contains "${output}" "Removes stopped service containers" "rm.sh --help"

  output="$("${REPO_ROOT}/scripts/docker/up.sh" invalid-service 2>&1 || true)"
  assert_output_contains "${output}" "Unknown service: invalid-service" "up.sh invalid-service"

  output="$("${REPO_ROOT}/scripts/docker/logs.sh" invalid-service 2>&1 || true)"
  assert_output_contains "${output}" "Unknown service: invalid-service" "logs.sh invalid-service"

  output="$(bash -lc 'source "'"${REPO_ROOT}"'/scripts/shared/common.sh"; false' 2>&1 || true)"
  assert_output_contains "${output}" "bash failed." "shared common error trap"
  assert_output_contains "${output}" "Command: false" "shared common error trap"

  run_compose config --quiet

  log_success 'Static Docker workflow checks passed.'
}

require_image() {
  local image="$1"
  docker image inspect "${image}" >/dev/null 2>&1 || die "Required image not found: ${image}. Build it first."
}

run_runtime_tests() {
  log_info 'Running runtime Docker workflow checks...'

  require_image "${CLI_IMAGE}"

  local output

  output="$("${REPO_ROOT}/scripts/docker/run.sh" --version)"
  assert_output_contains "${output}" "arnis " "run.sh --version"

  output="$("${REPO_ROOT}/scripts/docker/run.sh" arnis --version)"
  assert_output_contains "${output}" "arnis " "run.sh arnis --version"

  "${REPO_ROOT}/scripts/docker/ps.sh" --all >/dev/null

  output="$("${REPO_ROOT}/scripts/docker/run.sh" arnis-gui-headless 2>&1 || true)"
  assert_output_contains "${output}" "Use ./scripts/docker/gui-headless.sh" "run.sh arnis-gui-headless guard"

  log_success 'Runtime Docker workflow checks passed.'
}

run_headless_tests() {
  log_info 'Running headless GUI Docker workflow checks...'

  require_image "${HEADLESS_IMAGE}"

  cleanup() {
    "${REPO_ROOT}/scripts/docker/gui-headless.sh" down >/dev/null 2>&1 || true
  }

  trap cleanup EXIT INT TERM

  "${REPO_ROOT}/scripts/docker/gui-headless.sh" up >/dev/null
  sleep "${HEADLESS_WAIT_SECONDS}"

  local output
  output="$("${REPO_ROOT}/scripts/docker/gui-headless.sh" status)"
  assert_output_contains "${output}" "arnis-gui" "gui-headless.sh status"
  assert_output_contains "${output}" "VNC endpoint:" "gui-headless.sh status"

  "${REPO_ROOT}/scripts/docker/gui-headless.sh" logs >/dev/null 2>&1 &
  local logs_pid="$!"
  sleep 1
  kill "${logs_pid}" >/dev/null 2>&1 || true
  wait "${logs_pid}" >/dev/null 2>&1 || true

  cleanup
  trap - EXIT INT TERM

  log_success 'Headless GUI Docker workflow checks passed.'
}

print_help() {
  log_plain 'Usage: smoke.sh [static|runtime|headless|all]'
  log_plain
  log_plain 'Runs smoke tests for the Docker workflow.'
  log_plain
  log_plain 'Modes:'
  log_plain '  static    Syntax, help text, env example, and docker compose config checks'
  log_plain '  runtime   CLI/runtime smoke checks (requires built Docker images)'
  log_plain '  headless  Headless GUI smoke checks (requires built headless Docker image)'
  log_plain '  all       Run static, runtime, and headless checks'
}

case "${1:-static}" in
  -h|--help)
    print_help
    ;;
  static)
    run_static_tests
    ;;
  runtime)
    run_runtime_tests
    ;;
  headless)
    run_headless_tests
    ;;
  all)
    run_static_tests
    run_runtime_tests
    run_headless_tests
    ;;
  *)
    print_help >&2
    exit 1
    ;;
esac
