#!/usr/bin/env bash
# Thin runner for unit-preflight.sh: resolves REPO_ROOT from its own location,
# sources docker.sh + common.sh directly (no lib.sh to avoid $0 path confusion),
# then replicates and invokes preflight_teardown.

set -Eeuo pipefail

RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
# shared/ -> docker/ -> tests/ -> repo root
REPO_ROOT="$(cd "${RUNNER_DIR}/../../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/shared/docker.sh"

preflight_teardown() {
  local running=""
  running="$(run_compose ps --status running --services 2>/dev/null || true)"
  if [ -n "${running}" ]; then
    log_warn "Pre-flight: stopping running compose services before test: $(printf '%s' "${running}" | tr '\n' ' ')"
    run_compose down --timeout 10 2>/dev/null || true
  fi
}

preflight_teardown
