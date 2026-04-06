#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"

run_mode() {
  local mode="$1"
  bash "${TEST_DIR}/${mode}.sh"
}

print_help() {
  echo 'Usage: smoke.sh [static|unit|runtime|headless|e2e-cli|e2e-gui|e2e|all]'
  echo
  echo 'Runs Docker test suites.'
  echo
  echo 'Modes:'
  echo '  static    Syntax, help text, env example, and docker compose config checks'
  echo '  unit      Unit tests for shared scripts and entrypoint logic (no Docker required)'
  echo '  runtime   CLI/runtime smoke checks (requires built Docker images)'
  echo '  headless  Headless GUI smoke checks (requires built headless Docker image)'
  echo '  e2e-cli   CLI end-to-end checks (world generation + artifact verification)'
  echo '  e2e-gui   Headless GUI end-to-end checks (VNC handshake + restart + generation while GUI is running)'
  echo '  e2e       Run both e2e-cli and e2e-gui checks'
  echo '  all       Run static, unit, runtime, headless, and e2e suites'
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
