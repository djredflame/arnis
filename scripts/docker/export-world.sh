#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"

DOCKER_COPY_IMAGE="${ARNIS_DOCKER_COPY_IMAGE:-alpine:latest}"
DATA_VOLUME="${ARNIS_DATA_VOLUME:-arnis_data}"
DEFAULT_EXPORT_DIR="${ARNIS_WORLD_EXPORT_DIR:-${PWD}/exports}"

print_help() {
  print_usage_header '[--list] [WORLD_NAME] [EXPORT_DIR]'
  log_plain
  log_plain 'Exports generated worlds from the Docker volume to the host filesystem.'
  print_repo_hint
  log_plain
  print_compose_env_hint
  log_plain
  log_plain 'Behavior:'
  log_plain '  --list                Show worlds detected in the data volume and exit.'
  log_plain '  WORLD_NAME            Name of the world directory or .mcworld file (without extension).'
  log_plain "  EXPORT_DIR            Host destination directory (default: ${DEFAULT_EXPORT_DIR})."
  log_plain
  print_examples_header
  log_plain '  ./scripts/docker/export-world.sh --list'
  log_plain '  ./scripts/docker/export-world.sh "Arnis World 1"'
  log_plain '  ./scripts/docker/export-world.sh "Arnis World 1" "$HOME/Desktop"'
}

if is_help_flag "${1:-}"; then
  print_help
  exit 0
fi

list_worlds() {
  docker run --rm \
    -v "${DATA_VOLUME}:/data:ro" \
    "${DOCKER_COPY_IMAGE}" \
    sh -eu -c '
      found=0
      for entry in /data/*; do
        if [ -d "$entry" ] && [ -f "$entry/level.dat" ]; then
          printf "dir:%s\n" "$(basename "$entry")"
          found=1
        fi
      done

      for entry in /data/*.mcworld; do
        if [ -f "$entry" ]; then
          printf "mcworld:%s\n" "$(basename "$entry")"
          found=1
        fi
      done

      if [ "$found" -eq 0 ]; then
        exit 3
      fi
    '
}

if [ "${1:-}" = "--list" ]; then
  if worlds_output="$(list_worlds 2>/dev/null)"; then
    log_plain 'Detected worlds:'
    while IFS= read -r line; do
      case "$line" in
        dir:*)
          log_plain "  [DIR] ${line#dir:}"
          ;;
        mcworld:*)
          log_plain "  [MCWORLD] ${line#mcworld:}"
          ;;
      esac
    done <<< "${worlds_output}"
  else
    log_warn "No worlds were found in Docker volume '${DATA_VOLUME}'."
  fi
  exit 0
fi

world_name="${1:-}"
export_dir="${2:-${DEFAULT_EXPORT_DIR}}"

if [ -z "${world_name}" ]; then
  if worlds_output="$(list_worlds 2>/dev/null)"; then
    world_count="$(printf '%s\n' "${worlds_output}" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [ "${world_count}" = "1" ]; then
      single_entry="$(printf '%s\n' "${worlds_output}" | head -n 1)"
      case "${single_entry}" in
        dir:*) world_name="${single_entry#dir:}" ;;
        mcworld:*) world_name="${single_entry#mcworld:}" ;;
      esac
      world_name="${world_name%.mcworld}"
      log_note "Auto-selected world: ${world_name}"
    else
      log_error 'Multiple worlds found. Select one explicitly:'
      while IFS= read -r line; do
        case "$line" in
          dir:*)
            log_note_stderr "  ${line#dir:}"
            ;;
          mcworld:*)
            log_note_stderr "  ${line#mcworld:}"
            ;;
        esac
      done <<< "${worlds_output}"
      exit 1
    fi
  else
    die "No worlds found in volume '${DATA_VOLUME}'."
  fi
fi

mkdir -p "${export_dir}"
resolved_export_dir="$(cd "${export_dir}" && pwd)"

export_target_name="${world_name%.mcworld}"

if docker run --rm \
  -e WORLD_NAME="${world_name}" \
  -e EXPORT_TARGET_NAME="${export_target_name}" \
  -v "${DATA_VOLUME}:/data:ro" \
  -v "${resolved_export_dir}:/out" \
  "${DOCKER_COPY_IMAGE}" \
  sh -eu -c '
    if [ -f "/data/${WORLD_NAME}" ]; then
      cp -f "/data/${WORLD_NAME}" "/out/${WORLD_NAME}"
      exit 0
    fi

    if [ -f "/data/${WORLD_NAME}.mcworld" ]; then
      cp -f "/data/${WORLD_NAME}.mcworld" "/out/${EXPORT_TARGET_NAME}.mcworld"
      exit 0
    fi

    if [ -f "/data/${WORLD_NAME}/level.dat" ]; then
      rm -rf "/out/${EXPORT_TARGET_NAME}"
      cp -a "/data/${WORLD_NAME}" "/out/${EXPORT_TARGET_NAME}"
      exit 0
    fi

    exit 2
  '; then
  if [ -d "${resolved_export_dir}/${export_target_name}" ]; then
    log_success "Exported world directory to: ${resolved_export_dir}/${export_target_name}"
  elif [ -f "${resolved_export_dir}/${export_target_name}.mcworld" ]; then
    log_success "Exported .mcworld package to: ${resolved_export_dir}/${export_target_name}.mcworld"
  elif [ -f "${resolved_export_dir}/${world_name}" ]; then
    log_success "Exported file to: ${resolved_export_dir}/${world_name}"
  else
    log_success "Export completed in: ${resolved_export_dir}"
  fi
else
  die "World '${world_name}' was not found in volume '${DATA_VOLUME}'. Use --list to inspect available worlds."
fi
