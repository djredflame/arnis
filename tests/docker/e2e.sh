#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"

run_mode() {
  local mode="$1"
  bash "${TEST_DIR}/${mode}.sh"
}

print_help() {
  echo 'Usage: e2e.sh [cli|gui|all]'
  echo
  echo 'Runs Docker end-to-end suites.'
  echo
  echo 'Modes:'
  echo '  cli       CLI end-to-end checks (world generation + artifact verification)'
  echo '  gui       Headless GUI end-to-end checks (VNC handshake + restart + generation while GUI is running)'
  echo '  all       Run both cli and gui end-to-end checks'
}

case "${1:-all}" in
  -h|--help)
    print_help
    ;;
  cli)
    run_mode e2e-cli
    ;;
  gui)
    run_mode e2e-gui
    ;;
  all)
    run_mode e2e-cli
    run_mode e2e-gui
    ;;
  *)
    print_help >&2
    exit 1
    ;;
esac
