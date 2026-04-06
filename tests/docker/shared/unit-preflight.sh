#!/usr/bin/env bash

[ "${ARNIS_TEST_UNIT_PREFLIGHT_LOADED:-0}" = "1" ] && return 0
ARNIS_TEST_UNIT_PREFLIGHT_LOADED=1

run_unit_preflight_tests() {
  local mock_bin output exit_code

  # --- Case 1: no running services -> no WARN output, no compose down ---
  mock_bin="$(mktemp -d)"
  cat > "${mock_bin}/docker" <<'MEOF'
#!/bin/sh
case "$*" in
  *"--status running --services"*) exit 0 ;;
  *) printf "MOCK_DOCKER %s\n" "$*"; exit 0 ;;
esac
MEOF
  chmod +x "${mock_bin}/docker"

  output="$(
    PATH="${mock_bin}:${PATH}" \
    ARNIS_DISABLE_OS_COMPOSE_OVERRIDE=1 \
    ARNIS_LOG_COLOR=never \
    bash "${TEST_DIR}/shared/unit-preflight-runner.sh" 2>&1 || true
  )"
  case "${output}" in
    *'[WARN]'*|*'Pre-flight'*)
      die "preflight_teardown (no-op): must not log WARN when nothing is running; got: ${output}" ;;
  esac
  rm -rf "${mock_bin}"

  # --- Case 2: running services -> WARN logged and compose down invoked ---
  mock_bin="$(mktemp -d)"
  cat > "${mock_bin}/docker" <<'MEOF'
#!/bin/sh
case "$*" in
  *"--status running --services"*) printf "arnis-gui-headless\n"; exit 0 ;;
  *"down"*) printf "MOCK_DOCKER_DOWN\n"; exit 0 ;;
  *) printf "MOCK_DOCKER %s\n" "$*"; exit 0 ;;
esac
MEOF
  chmod +x "${mock_bin}/docker"

  output="$(
    PATH="${mock_bin}:${PATH}" \
    ARNIS_DISABLE_OS_COMPOSE_OVERRIDE=1 \
    ARNIS_LOG_COLOR=never \
    bash "${TEST_DIR}/shared/unit-preflight-runner.sh" 2>&1 || true
  )"
  case "${output}" in
    *'Pre-flight'*) ;;
    *) die "preflight_teardown (teardown): expected Pre-flight WARN; got: ${output}" ;;
  esac
  case "${output}" in
    *'arnis-gui-headless'*) ;;
    *) die "preflight_teardown (teardown): expected service name in WARN; got: ${output}" ;;
  esac
  case "${output}" in
    *'MOCK_DOCKER_DOWN'*) ;;
    *) die "preflight_teardown (teardown): expected compose down to be called; got: ${output}" ;;
  esac
  rm -rf "${mock_bin}"

  # --- Case 3: compose ps fails (permission error etc.) -> must not abort ---
  mock_bin="$(mktemp -d)"
  cat > "${mock_bin}/docker" <<'MEOF'
#!/bin/sh
exit 1
MEOF
  chmod +x "${mock_bin}/docker"

  exit_code=0
  PATH="${mock_bin}:${PATH}" \
  ARNIS_DISABLE_OS_COMPOSE_OVERRIDE=1 \
  ARNIS_LOG_COLOR=never \
  bash "${TEST_DIR}/shared/unit-preflight-runner.sh" >/dev/null 2>&1 || exit_code=$?
  [ "${exit_code}" -eq 0 ] || die "preflight_teardown must not abort when compose ps fails; exit=${exit_code}"
  rm -rf "${mock_bin}"
}
