#!/usr/bin/env bash

[ "${ARNIS_DOCKER_SERVICES_LOADED:-0}" = "1" ] && return 0
ARNIS_DOCKER_SERVICES_LOADED=1

is_known_service() {
  case "${1:-}" in
    arnis|arnis-gui|arnis-gui-headless|arnis-test-live)
      return 0
      ;;
  esac
  return 1
}

require_known_service() {
  local service="${1:-}"

  case "${service}" in
    arnis|arnis-gui|arnis-gui-headless|arnis-test-live)
      return 0
      ;;
    *)
      die "Unknown service: ${service}"
      ;;
  esac
}

print_supported_services() {
  log_plain 'Supported services:'
  log_plain '  arnis              CLI generation and headless runs'
  log_plain '  arnis-gui          Linux desktop GUI only (requires X11 on the host)'
  log_plain '  arnis-gui-headless Linux desktop GUI over VNC (Docker-only headless path)'
  log_plain '  arnis-test-live    Full live test suite'
}