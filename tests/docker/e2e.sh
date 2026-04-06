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
  log_plain 'Usage: e2e.sh [cli|gui|export|all]'
  log_plain
  log_plain 'Runs Docker end-to-end suites.'
  log_plain
  log_plain 'Modes:'
  log_plain '  cli       CLI end-to-end checks (world generation + artifact verification)'
  log_plain '  gui       Headless GUI end-to-end checks (VNC handshake + restart + generation while GUI is running)'
  log_plain '  export    Export end-to-end checks (world export-world.sh --list and real export verification)'
  log_plain '  all       Run cli, gui, and export end-to-end checks'
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
  export)
    run_mode e2e-export
    ;;
  all)
    run_mode e2e-cli
    run_mode e2e-gui
    run_mode e2e-export
    ;;
  *)
    print_help >&2
    exit 1
    ;;
esac
