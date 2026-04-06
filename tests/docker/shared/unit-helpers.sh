#!/usr/bin/env bash

[ "${ARNIS_TEST_UNIT_HELPERS_LOADED:-0}" = "1" ] && return 0
ARNIS_TEST_UNIT_HELPERS_LOADED=1

assert_output_lacks_shell_failure() {
  local output="$1"
  local context="$2"

  case "${output}" in
    *'unbound variable'*|*'bad substitution'*|*'syntax error near unexpected token'*)
      die "${context} triggered a shell failure: ${output}"
      ;;
  esac
}

setup_mock_docker() {
  mock_docker_bin="$(mktemp -d)"
  cat > "${mock_docker_bin}/docker" <<'EOF'
#!/bin/sh
printf 'MOCK_DOCKER %s\n' "$*"
exit 0
EOF
  chmod +x "${mock_docker_bin}/docker"
}

run_mocked_script() {
  local script_path="$1"
  shift || true

  PATH="${mock_docker_bin}:${PATH}" \
  ARNIS_DISABLE_OS_COMPOSE_OVERRIDE=1 \
  ARNIS_LOG_COLOR=never \
  bash "${script_path}" "$@" 2>&1
}

cleanup_unit_artifacts() {
  rm -rf "${mock_docker_bin:-}"
}