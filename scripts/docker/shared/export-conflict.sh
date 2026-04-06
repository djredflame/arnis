#!/usr/bin/env bash
# Sourced by export-world.sh. Requires: WORLD_TYPES, WORLD_NAMES (caller),
# shared logger functions, die(), and export-discovery functions.

[ "${EXPORT_CONFLICT_LOADED:-0}" = "1" ] && return 0
EXPORT_CONFLICT_LOADED=1

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
