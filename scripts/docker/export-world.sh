#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../shared/docker.sh"

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

discover_worlds() {
  WORLD_TYPES=()
  WORLD_NAMES=()

  local worlds_output line type name
  if ! worlds_output="$(list_worlds 2>/dev/null)"; then
    return 1
  fi

  while IFS= read -r line; do
    [ -n "${line}" ] || continue
    type="${line%%:*}"
    name="${line#*:}"
    case "${type}" in
      dir|mcworld)
        WORLD_TYPES+=("${type}")
        WORLD_NAMES+=("${name}")
        ;;
    esac
  done <<< "${worlds_output}"

  [ "${#WORLD_TYPES[@]}" -gt 0 ]
}

print_detected_worlds() {
  local i
  log_plain 'Detected worlds:'
  for i in "${!WORLD_TYPES[@]}"; do
    case "${WORLD_TYPES[$i]}" in
      dir)
        log_plain "  [DIR] ${WORLD_NAMES[$i]}"
        ;;
      mcworld)
        log_plain "  [MCWORLD] ${WORLD_NAMES[$i]}"
        ;;
    esac
  done
}

target_exists() {
  local export_dir="$1"
  local name="$2"
  local kind="$3"

  case "${kind}" in
    dir)
      [ -e "${export_dir}/${name}" ]
      ;;
    mcworld)
      [ -e "${export_dir}/${name}.mcworld" ]
      ;;
    *)
      return 1
      ;;
  esac
}

generate_copy_name() {
  local export_dir="$1"
  local base_name="$2"
  local kind="$3"
  local candidate="${base_name} (copy)"
  local index=2

  while target_exists "${export_dir}" "${candidate}" "${kind}"; do
    candidate="${base_name} (copy ${index})"
    index=$((index + 1))
  done

  printf '%s\n' "${candidate}"
}

resolve_conflict_name() {
  local export_dir="$1"
  local base_name="$2"
  local kind="$3"
  local conflict_mode="$4"
  local mode_choice="${conflict_mode}"

  if ! target_exists "${export_dir}" "${base_name}" "${kind}"; then
    printf '%s\n' "${base_name}"
    return 0
  fi

  if [ "${mode_choice}" = "ask" ]; then
    if [ -t 0 ]; then
      log_warn "Export target already exists: ${base_name}"
      while :; do
        log_note_stderr 'Choose what to do:'
        log_note_stderr '  1) Overwrite existing export'
        log_note_stderr '  2) Create copy (recommended)'
        log_note_stderr '  3) Skip this world'
        printf 'Selection [2]: ' >&2
        read -r mode_choice
        case "${mode_choice}" in
          1|o|O|overwrite)
            mode_choice="overwrite"
            break
            ;;
          2|c|C|copy|'')
            mode_choice="copy"
            break
            ;;
          3|s|S|skip)
            mode_choice="skip"
            break
            ;;
          *)
            log_note_stderr 'Please enter 1, 2, or 3.'
            ;;
        esac
      done
    else
      log_warn "Target '${base_name}' already exists; non-interactive mode defaults to copy."
      mode_choice="copy"
    fi
  fi

  case "${mode_choice}" in
    overwrite)
      printf '__OVERWRITE__\n'
      ;;
    copy)
      generate_copy_name "${export_dir}" "${base_name}" "${kind}"
      ;;
    skip)
      printf '__SKIP__\n'
      ;;
    *)
      die "Invalid conflict mode '${mode_choice}'. Expected ask|overwrite|copy|skip."
      ;;
  esac
}

export_world_dir() {
  local world_dir_name="$1"
  local export_dir="$2"
  local target_name="$3"
  local overwrite_existing="$4"
  local export_mount_path=""

  export_mount_path="$(to_docker_host_path "${export_dir}")"

  docker run --rm \
    -v "${DATA_VOLUME}:/data:ro" \
    -v "${export_mount_path}:/out" \
    "${DOCKER_COPY_IMAGE}" \
    sh -eu -c '
      src="$1"
      target="$2"
      overwrite="$3"

      [ -f "/data/$src/level.dat" ]
      if [ "$overwrite" = "1" ]; then
        rm -rf "/out/$target"
      fi
      cp -a "/data/$src" "/out/$target"
    ' sh "${world_dir_name}" "${target_name}" "${overwrite_existing}" >/dev/null
}

export_mcworld_file() {
  local mcworld_file_name="$1"
  local export_dir="$2"
  local target_file_name="$3"
  local export_mount_path=""

  export_mount_path="$(to_docker_host_path "${export_dir}")"

  docker run --rm \
    -v "${DATA_VOLUME}:/data:ro" \
    -v "${export_mount_path}:/out" \
    "${DOCKER_COPY_IMAGE}" \
    sh -eu -c '
      src="$1"
      target="$2"
      [ -f "/data/$src" ]
      cp -f "/data/$src" "/out/$target"
    ' sh "${mcworld_file_name}" "${target_file_name}" >/dev/null
}

interactive_select() {
  local i choice

  print_detected_worlds
  log_plain '  [ALL] all worlds'

  while :; do
    printf 'Select world number, "all", or "q": ' >&2
    read -r choice
    case "${choice}" in
      q|Q)
        die 'Selection cancelled.'
        ;;
      all|ALL|a|A)
        printf '__ALL__\n'
        return 0
        ;;
      ''|*[!0-9]*)
        log_note_stderr 'Please enter a valid number, "all", or "q".'
        ;;
      *)
        i=$((choice - 1))
        if [ "${i}" -ge 0 ] && [ "${i}" -lt "${#WORLD_TYPES[@]}" ]; then
          printf '%s\n' "${i}"
          return 0
        fi
        log_note_stderr 'Selection out of range.'
        ;;
    esac
  done
}

resolve_named_world_index() {
  local requested_name="$1"
  local matches=()
  local i

  for i in "${!WORLD_TYPES[@]}"; do
    if [ "${requested_name}" = "${WORLD_NAMES[$i]}" ]; then
      matches+=("${i}")
      continue
    fi

    if [ "${WORLD_TYPES[$i]}" = "mcworld" ] && [ "${requested_name}" = "${WORLD_NAMES[$i]%.mcworld}" ]; then
      matches+=("${i}")
    fi
  done

  if [ "${#matches[@]}" -eq 0 ]; then
    return 1
  fi

  if [ "${#matches[@]}" -gt 1 ]; then
    die "World name '${requested_name}' is ambiguous. Use the exact directory or .mcworld filename."
  fi

  printf '%s\n' "${matches[0]}"
}

to_docker_host_path() {
  local input_path="$1"
  local os_name=""

  os_name="$(uname -s 2>/dev/null || printf unknown)"

  case "${os_name}" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      if command -v cygpath >/dev/null 2>&1; then
        cygpath -am "${input_path}"
        return 0
      fi

      if converted_path="$(cd "${input_path}" 2>/dev/null && pwd -W 2>/dev/null)"; then
        printf '%s\n' "${converted_path}"
        return 0
      fi

      ;;
  esac

  printf '%s\n' "${input_path}"
}

export_entry_by_index() {
  local index="$1"
  local export_dir="$2"
  local conflict_mode="$3"
  local entry_type="${WORLD_TYPES[$index]}"
  local entry_name="${WORLD_NAMES[$index]}"
  local base_name target_name overwrite_existing

  case "${entry_type}" in
    dir)
      base_name="${entry_name}"
      target_name="$(resolve_conflict_name "${export_dir}" "${base_name}" "dir" "${conflict_mode}")"
      case "${target_name}" in
        __SKIP__)
          log_warn "Skipped world directory: ${base_name}"
          return 0
          ;;
        __OVERWRITE__)
          overwrite_existing=1
          target_name="${base_name}"
          ;;
        *)
          overwrite_existing=0
          ;;
      esac

      export_world_dir "${entry_name}" "${export_dir}" "${target_name}" "${overwrite_existing}"
      log_success "Exported world directory to: ${export_dir}/${target_name}"
      ;;
    mcworld)
      base_name="${entry_name%.mcworld}"
      target_name="$(resolve_conflict_name "${export_dir}" "${base_name}" "mcworld" "${conflict_mode}")"
      case "${target_name}" in
        __SKIP__)
          log_warn "Skipped .mcworld package: ${entry_name}"
          return 0
          ;;
        __OVERWRITE__)
          target_name="${base_name}"
          ;;
      esac

      export_mcworld_file "${entry_name}" "${export_dir}" "${target_name}.mcworld"
      log_success "Exported .mcworld package to: ${export_dir}/${target_name}.mcworld"
      ;;
    *)
      die "Unsupported world type '${entry_type}'."
      ;;
  esac
}

if [ "${1:-}" = "--list" ]; then
  if discover_worlds; then
    print_detected_worlds
  else
    log_warn "No worlds were found in Docker volume '${DATA_VOLUME}'."
  fi
  exit 0
fi

list_only=0
all_mode=0
select_mode=0
conflict_mode='ask'
positionals=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --list)
      list_only=1
      shift
      ;;
    --all)
      all_mode=1
      shift
      ;;
    --select)
      select_mode=1
      shift
      ;;
    --on-conflict)
      [ "$#" -ge 2 ] || die '--on-conflict requires a value.'
      conflict_mode="$2"
      shift 2
      ;;
    --on-conflict=*)
      conflict_mode="${1#*=}"
      shift
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        positionals+=("$1")
        shift
      done
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      positionals+=("$1")
      shift
      ;;
  esac
done

case "${conflict_mode}" in
  ask|overwrite|copy|skip)
    ;;
  *)
    die "Invalid --on-conflict value '${conflict_mode}'. Expected ask|overwrite|copy|skip."
    ;;
esac

world_name=''
export_dir="${DEFAULT_EXPORT_DIR}"

if [ "${all_mode}" -eq 1 ]; then
  [ "${#positionals[@]}" -le 1 ] || die '--all accepts at most one positional argument: EXPORT_DIR.'
  if [ "${#positionals[@]}" -eq 1 ]; then
    export_dir="${positionals[0]}"
  fi
elif [ "${select_mode}" -eq 1 ]; then
  [ "${#positionals[@]}" -le 1 ] || die '--select accepts at most one positional argument: EXPORT_DIR.'
  if [ "${#positionals[@]}" -eq 1 ]; then
    export_dir="${positionals[0]}"
  fi
else
  [ "${#positionals[@]}" -le 2 ] || die 'Expected at most two positional arguments: WORLD_NAME [EXPORT_DIR].'
  if [ "${#positionals[@]}" -ge 1 ]; then
    world_name="${positionals[0]}"
  fi
  if [ "${#positionals[@]}" -eq 2 ]; then
    export_dir="${positionals[1]}"
  fi
fi

if [ "${list_only}" -eq 1 ]; then
  if discover_worlds; then
    print_detected_worlds
  else
    log_warn "No worlds were found in Docker volume '${DATA_VOLUME}'."
  fi
  exit 0
fi

if ! discover_worlds; then
  die "No worlds found in volume '${DATA_VOLUME}'."
fi

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
  if ! selected_index="$(resolve_named_world_index "${world_name}")"; then
    die "World '${world_name}' was not found in volume '${DATA_VOLUME}'. Use --list to inspect available worlds."
  fi
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
