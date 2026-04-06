#!/usr/bin/env bash
# Sourced by export-world.sh. Requires: DATA_VOLUME, DOCKER_COPY_IMAGE,
# WORLD_TYPES, WORLD_NAMES (declared by caller), and shared logger functions.

[ "${EXPORT_DISCOVERY_LOADED:-0}" = "1" ] && return 0
EXPORT_DISCOVERY_LOADED=1

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
