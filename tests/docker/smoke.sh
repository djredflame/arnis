#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${TEST_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/shared/common.sh"

run_mode() {
  local mode="$1"
  bash "${TEST_DIR}/${mode}.sh"
}

print_help() {
  log_plain 'Usage: smoke.sh [static|unit|runtime|headless|e2e-cli|e2e-gui|e2e-export|e2e|all]'
  log_plain
  log_plain 'Runs Docker test suites.'
  log_plain
  log_plain 'Modes:'
  log_plain '  static    Syntax, help text, env example, and docker compose config checks'
  log_plain '  unit      Unit tests for shared scripts and entrypoint logic (no Docker required)'
  log_plain '  runtime   CLI/runtime smoke checks (requires built Docker images)'
  log_plain '  headless  Headless GUI smoke checks (requires built headless Docker image)'
  log_plain '  e2e-cli   CLI end-to-end checks (world generation + artifact verification)'
  log_plain '  e2e-gui   Headless GUI end-to-end checks (VNC handshake + restart + generation while GUI is running)'
  log_plain '  e2e-export Export end-to-end checks (export-world.sh list + real export verification)'
  log_plain '  e2e       Run e2e-cli, e2e-gui, and e2e-export checks'
  log_plain '  all       Run static, unit, runtime, headless, and e2e suites'
}

case "${1:-static}" in
  -h|--help)
    print_help
    ;;
  static|unit|runtime|headless)
    run_mode "$1"
    ;;
  e2e-cli)
    run_mode e2e-cli
    ;;
  e2e-gui)
    run_mode e2e-gui
    ;;
  e2e-export)
    run_mode e2e-export
    ;;
  e2e)
    run_mode e2e
    ;;
  all)
    run_mode static
    run_mode unit
    run_mode runtime
    run_mode headless
    run_mode e2e
    ;;
  *)
    print_help >&2
    exit 1
    ;;
esac
