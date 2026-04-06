#!/usr/bin/env bash

set -Eeuo pipefail

[ "${ARNIS_DOCKER_SH_LOADED:-0}" = "1" ] && return 0
ARNIS_DOCKER_SH_LOADED=1

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SHARED_DIR}/../.." && pwd)"
DOCKER_ENV_FILE="${REPO_ROOT}/.env.docker"
DEFAULT_RUN_SERVICE="arnis"
BASE_COMPOSE_FILE="${REPO_ROOT}/docker-compose.yml"

# Keep explicit process-level override even when .env.docker provides defaults.
_ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_ORIG="${ARNIS_DISABLE_OS_COMPOSE_OVERRIDE-}"
_ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_WAS_SET="${ARNIS_DISABLE_OS_COMPOSE_OVERRIDE+x}"

# shellcheck disable=SC1091
source "${SHARED_DIR}/common.sh"

if [ -f "${DOCKER_ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${DOCKER_ENV_FILE}"
  set +a
fi

if [ "${_ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_WAS_SET}" = "x" ]; then
  ARNIS_DISABLE_OS_COMPOSE_OVERRIDE="${_ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_ORIG}"
fi

unset _ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_ORIG
unset _ARNIS_DISABLE_OS_COMPOSE_OVERRIDE_WAS_SET

# shellcheck disable=SC1091
source "${SHARED_DIR}/docker-services.sh"
# shellcheck disable=SC1091
source "${SHARED_DIR}/docker-help.sh"
# shellcheck disable=SC1091
source "${SHARED_DIR}/docker-display.sh"
# shellcheck disable=SC1091
source "${SHARED_DIR}/docker-compose.sh"
