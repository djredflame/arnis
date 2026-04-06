#!/usr/bin/env bash

[ "${ARNIS_TEST_UNIT_ENTRYPOINTS_LOADED:-0}" = "1" ] && return 0
ARNIS_TEST_UNIT_ENTRYPOINTS_LOADED=1

run_unit_entrypoint_tests() {
  # Shell entrypoints: help/no-arg paths should not explode under set -u.
  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/build.sh")" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 0 ] || die "build.sh no-arg path: expected exit 0, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'build.sh no-arg path'
  assert_output_contains "${output}" 'Building without build-time cargo test validation.' 'build.sh no-arg log'
  assert_output_contains "${output}" 'MOCK_DOCKER compose' 'build.sh no-arg compose invocation'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/build.sh" --with-tests)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 0 ] || die "build.sh --with-tests path: expected exit 0, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'build.sh --with-tests path'
  assert_output_contains "${output}" 'Building with build-time cargo test validation enabled.' 'build.sh --with-tests log'
  assert_output_contains "${output}" 'MOCK_DOCKER compose' 'build.sh --with-tests compose invocation'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/down.sh")" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 0 ] || die "down.sh no-arg path: expected exit 0, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'down.sh no-arg path'
  assert_output_contains "${output}" 'MOCK_DOCKER compose' 'down.sh no-arg compose invocation'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/ps.sh")" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 0 ] || die "ps.sh no-arg path: expected exit 0, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'ps.sh no-arg path'
  assert_output_contains "${output}" 'MOCK_DOCKER compose' 'ps.sh no-arg compose invocation'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/rm.sh")" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 0 ] || die "rm.sh no-arg path: expected exit 0, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'rm.sh no-arg path'
  assert_output_contains "${output}" 'MOCK_DOCKER compose' 'rm.sh no-arg compose invocation'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/logs.sh")" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 1 ] || die "logs.sh no-arg path: expected exit 1, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'logs.sh no-arg path'
  assert_output_contains "${output}" 'No service specified.' 'logs.sh no-arg message'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/up.sh")" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 1 ] || die "up.sh no-arg path: expected exit 1, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'up.sh no-arg path'
  assert_output_contains "${output}" 'No service specified.' 'up.sh no-arg message'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/run.sh")" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 1 ] || die "run.sh no-arg path: expected exit 1, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'run.sh no-arg path'
  assert_output_contains "${output}" 'When SERVICE is omitted' 'run.sh no-arg help output'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/run.sh" arnis --version)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 0 ] || die "run.sh passthrough path: expected exit 0, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'run.sh passthrough path'
  assert_output_contains "${output}" 'MOCK_DOCKER compose' 'run.sh passthrough compose invocation'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/gui-headless.sh")" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 1 ] || die "gui-headless.sh no-arg path: expected exit 1, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'gui-headless.sh no-arg path'
  assert_output_contains "${output}" 'This helper is optional and only intended for headless Linux hosts.' 'gui-headless.sh no-arg help output'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/x11-host.sh")" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 1 ] || die "x11-host.sh no-arg path: expected exit 1, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'x11-host.sh no-arg path'
  assert_output_contains "${output}" 'Usage: x11-host.sh {up|down|status|logs}' 'x11-host.sh no-arg usage'

  trap - ERR
  exit_code=0
  output="$(run_mocked_script "${REPO_ROOT}/scripts/docker/test.sh" --help)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 0 ] || die "test.sh --help path: expected exit 0, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'test.sh --help path'
  assert_output_contains "${output}" 'Usage: smoke.sh' 'test.sh forwards smoke.sh help'

  trap - ERR
  exit_code=0
  output="$(ARNIS_LOG_COLOR=never bash "${REPO_ROOT}/tests/docker/smoke.sh" --help 2>&1)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 0 ] || die "smoke.sh --help path: expected exit 0, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'smoke.sh --help path'
  assert_output_contains "${output}" 'Usage: smoke.sh' 'smoke.sh help output'

  trap - ERR
  exit_code=0
  output="$(ARNIS_LOG_COLOR=never bash "${REPO_ROOT}/tests/docker/e2e.sh" --help 2>&1)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 0 ] || die "e2e.sh --help path: expected exit 0, got ${exit_code}"
  assert_output_lacks_shell_failure "${output}" 'e2e.sh --help path'
  assert_output_contains "${output}" 'Usage: e2e.sh' 'e2e.sh help output'
}