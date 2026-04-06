#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shared/export-discovery.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shared/export-conflict.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shared/export-io.sh"

DOCKER_COPY_IMAGE="${ARNIS_DOCKER_COPY_IMAGE:-alpine:latest}"
DATA_VOLUME="${ARNIS_DATA_VOLUME:-arnis_data}"
DEFAULT_EXPORT_DIR="${ARNIS_WORLD_EXPORT_DIR:-${PWD}/exports}"

WORLD_TYPES=()
WORLD_NAMES=()

print_help() {
  print_usage_header '[--list] [--all] [--select] [--on-conflict MODE] [WORLD_NAME] [EXPORT_DIR]'
  log_plain
  log_plain 'Exports generated worlds from the Docker volume to the host filesystem.'
  print_repo_hint
  log_plain
  print_compose_env_hint
  log_plain
  log_plain 'Behavior:'
  log_plain '  --list                Show worlds detected in the data volume and exit.'
  log_plain '  --all                 Export all detected worlds.'
  log_plain '  --select              Interactively choose world(s) when multiple exist.'
  log_plain '  --on-conflict MODE    Conflict mode: ask|overwrite|copy|skip (default: ask).'
  log_plain '  WORLD_NAME            Name of the world directory or .mcworld file (without extension).'
  log_plain "  EXPORT_DIR            Host destination directory (default: ${DEFAULT_EXPORT_DIR})."
  log_plain
  print_examples_header
  log_plain '  ./scripts/docker/export-world.sh --list'
  log_plain '  ./scripts/docker/export-world.sh --all'
  log_plain '  ./scripts/docker/export-world.sh --select "$HOME/Desktop"'
  log_plain '  ./scripts/docker/export-world.sh "Arnis World 1" --on-conflict copy'
  log_plain '  ./scripts/docker/export-world.sh "Arnis World 1"'
  log_plain '  ./scripts/docker/export-world.sh "Arnis World 1" "$HOME/Desktop"'
}

if is_help_flag "${1:-}"; then
  print_help
  exit 0
fi

# --- Argument parsing ---

list_only=0
all_mode=0
select_mode=0
conflict_mode='ask'
positionals=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --list)       list_only=1; shift ;;
    --all)        all_mode=1; shift ;;
    --select)     select_mode=1; shift ;;
    --on-conflict)
      [ "$#" -ge 2 ] || die '--on-conflict requires a value.'
      conflict_mode="$2"; shift 2 ;;
    --on-conflict=*)
      conflict_mode="${1#*=}"; shift ;;
    --help|-h)    print_help; exit 0 ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do positionals+=("$1"); shift; done ;;
    -*) die "Unknown option: $1" ;;
    *)  positionals+=("$1"); shift ;;
  esac
done

case "${conflict_mode}" in
  ask|overwrite|copy|skip) ;;
  *) die "Invalid --on-conflict value '${conflict_mode}'. Expected ask|overwrite|copy|skip." ;;
esac

world_name=''
export_dir="${DEFAULT_EXPORT_DIR}"

if [ "${all_mode}" -eq 1 ]; then
  [ "${#positionals[@]}" -le 1 ] || die '--all accepts at most one positional argument: EXPORT_DIR.'
  [ "${#positionals[@]}" -eq 1 ] && export_dir="${positionals[0]}"
elif [ "${select_mode}" -eq 1 ]; then
  [ "${#positionals[@]}" -le 1 ] || die '--select accepts at most one positional argument: EXPORT_DIR.'
  [ "${#positionals[@]}" -eq 1 ] && export_dir="${positionals[0]}"
else
  [ "${#positionals[@]}" -le 2 ] || die 'Expected at most two positional arguments: WORLD_NAME [EXPORT_DIR].'
  [ "${#positionals[@]}" -ge 1 ] && world_name="${positionals[0]}"
  [ "${#positionals[@]}" -eq 2 ] && export_dir="${positionals[1]}"
fi

# --- Execution ---

if [ "${list_only}" -eq 1 ]; then
  if discover_worlds; then
    print_detected_worlds
  else
    log_warn "No worlds were found in Docker volume '${DATA_VOLUME}'."
  fi
  exit 0
fi

discover_worlds || die "No worlds found in volume '${DATA_VOLUME}'."

mkdir -p "${export_dir}"
resolved_export_dir="$(cd "${export_dir}" && pwd)"

if [ "${all_mode}" -eq 1 ]; then
  for idx in "${!WORLD_TYPES[@]}"; do
    export_entry_by_index "${idx}" "${resolved_export_dir}" "${conflict_mode}"
  done
  exit 0
fi

if [ -z "${world_name}" ] && [ "${select_mode}" -eq 0 ] && [ "${#WORLD_TYPES[@]}" -eq 1 ]; then
  world_name="${WORLD_NAMES[0]}"
  log_note "Auto-selected world: ${world_name}"
fi

selected_index=''

if [ -n "${world_name}" ]; then
  selected_index="$(resolve_named_world_index "${world_name}")" \
    || die "World '${world_name}' was not found in volume '${DATA_VOLUME}'. Use --list to inspect available worlds."
elif [ "${#WORLD_TYPES[@]}" -gt 1 ] || [ "${select_mode}" -eq 1 ]; then
  if [ -t 0 ]; then
    selection="$(interactive_select)"
    if [ "${selection}" = '__ALL__' ]; then
      for idx in "${!WORLD_TYPES[@]}"; do
        export_entry_by_index "${idx}" "${resolved_export_dir}" "${conflict_mode}"
      done
      exit 0
    fi
    selected_index="${selection}"
  else
    die 'Multiple worlds found. Run with --select (interactive), --all, or pass WORLD_NAME explicitly.'
  fi
else
  selected_index='0'
fi

export_entry_by_index "${selected_index}" "${resolved_export_dir}" "${conflict_mode}"
