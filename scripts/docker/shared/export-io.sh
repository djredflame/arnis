#!/usr/bin/env bash
# Sourced by export-world.sh. Requires: DATA_VOLUME, DOCKER_COPY_IMAGE,
# WORLD_TYPES, WORLD_NAMES (caller), shared logger/die, and export-conflict
# functions (resolve_conflict_name).

[ "${EXPORT_IO_LOADED:-0}" = "1" ] && return 0
EXPORT_IO_LOADED=1

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
