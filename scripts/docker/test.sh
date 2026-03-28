#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/shared/common.sh"

# Wrapper around the Docker smoke tests under tests/ so contributors can
# discover and run them from the same scripts/docker entrypoint family.
exec "${REPO_ROOT}/tests/docker/smoke.sh" "$@"
