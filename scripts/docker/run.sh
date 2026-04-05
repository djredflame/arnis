#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"

print_help() {
  log_plain "When SERVICE is omitted, the default service is \"${DEFAULT_RUN_SERVICE}\"."
  log_plain
  log_plain 'Notes:'
  print_native_gui_note
  log_plain '  arnis-gui-headless is managed with ./scripts/docker/gui-headless.sh.'
  log_plain '  Use arnis for normal one-shot CLI runs.'
  print_headless_helper_note
  log_plain
  print_examples_header
  log_plain '  ./scripts/docker/run.sh --version'
  log_plain '  ./scripts/docker/run.sh arnis --version'
  log_plain '  ./scripts/docker/run.sh arnis --terrain --path=/data/world --bbox=46.9246,7.3521,46.9667,7.4139'
  log_plain '  ./scripts/docker/run.sh arnis-gui'
  log_plain '  ./scripts/docker/gui-headless.sh up'
  log_plain '  ./scripts/docker/run.sh arnis-test-live'
}

handle_compose_help "${1:-}" '[SERVICE] [ARGS...]' 'Runs a one-shot service command with docker compose run --rm.' true print_help

extract_path_arg() {
  local args=("$@")
  local index=0

  while [ "${index}" -lt "${#args[@]}" ]; do
    case "${args[index]}" in
      --path=*)
        printf '%s\n' "${args[index]#--path=}"
        return 0
        ;;
      --path)
        if [ $((index + 1)) -lt "${#args[@]}" ]; then
          printf '%s\n' "${args[index + 1]}"
          return 0
        fi
        ;;
    esac
    index=$((index + 1))
  done

  printf '\n'
}

ensure_container_path_exists() {
  local service="$1"
  local path_arg="$2"
  local escaped_path

  escaped_path="${path_arg//\\/\\\\}"
  escaped_path="${escaped_path//\"/\\\"}"

  run_compose run --rm --entrypoint sh "${service}" -c "mkdir -p \"${escaped_path}\"" >/dev/null
}

if [ "$#" -lt 1 ]; then
  print_help >&2
  exit 1
fi

service="${DEFAULT_RUN_SERVICE}"

case "${1:-}" in
  arnis|arnis-gui|arnis-gui-headless|arnis-test-live)
    service="$1"
    shift
    ;;
esac

if [ "${service}" = "arnis-gui" ]; then
  ensure_native_gui_display
fi

if [ "${service}" = "arnis-gui-headless" ]; then
  die "Use ./scripts/docker/gui-headless.sh for the Docker-only headless GUI workflow."
fi

if [ "${service}" = "arnis" ]; then
  path_arg="$(extract_path_arg "$@")"
  if [ -n "${path_arg}" ]; then
    ensure_container_path_exists "${service}" "${path_arg}"
  fi
fi

# Always remove the transient run container after the command exits.
run_compose run --rm "${service}" "$@"
