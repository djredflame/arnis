#!/usr/bin/env bash

[ "${ARNIS_TEST_UNIT_EXPORT_LOADED:-0}" = "1" ] && return 0
ARNIS_TEST_UNIT_EXPORT_LOADED=1

run_unit_export_tests() {
  output="$(ARNIS_LOG_COLOR=never ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-discovery.sh"
    list_worlds() {
      printf "dir:Arnis World 1\n"
      printf "mcworld:Arnis Pack.mcworld\n"
      printf "ignored:skip-me\n"
    }
    discover_worlds
    print_detected_worlds
    printf "COUNT=%s\n" "${#WORLD_TYPES[@]}"
    printf "FIRST=%s:%s\n" "${WORLD_TYPES[0]}" "${WORLD_NAMES[0]}"
    printf "SECOND=%s:%s\n" "${WORLD_TYPES[1]}" "${WORLD_NAMES[1]}"
  ')"
  assert_output_contains "${output}" 'Detected worlds:' 'export-discovery print header'
  assert_output_contains "${output}" '[DIR] Arnis World 1' 'export-discovery dir label'
  assert_output_contains "${output}" '[MCWORLD] Arnis Pack.mcworld' 'export-discovery mcworld label'
  assert_output_contains "${output}" 'COUNT=2' 'export-discovery parsed world count'
  assert_output_contains "${output}" 'FIRST=dir:Arnis World 1' 'export-discovery first entry'
  assert_output_contains "${output}" 'SECOND=mcworld:Arnis Pack.mcworld' 'export-discovery second entry'

  trap - ERR
  exit_code=0
  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-discovery.sh"
    list_worlds() { return 1; }
    discover_worlds && echo yes || echo no
  ' 2>&1)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 0 ] || die "export-discovery failure path: unexpected exit ${exit_code}"
  assert_output_contains "${output}" 'no' 'export-discovery returns false when list_worlds fails'

  tmp_export_dir="$(mktemp -d)"
  mkdir -p "${tmp_export_dir}/Arnis World 1" "${tmp_export_dir}/Arnis World 1 (copy)"
  touch "${tmp_export_dir}/Pack.mcworld" "${tmp_export_dir}/Pack (copy).mcworld"

  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" ARNIS_TMP_EXPORT_DIR="${tmp_export_dir}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-conflict.sh"
    target_exists "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir && echo DIR_EXISTS=yes
    target_exists "${ARNIS_TMP_EXPORT_DIR}" "Pack" mcworld && echo MCWORLD_EXISTS=yes
    printf "COPY_DIR=%s\n" "$(generate_copy_name "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir)"
    printf "COPY_FILE=%s\n" "$(generate_copy_name "${ARNIS_TMP_EXPORT_DIR}" "Pack" mcworld)"
    printf "ASK_DEFAULT=%s\n" "$(resolve_conflict_name "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir ask </dev/null)"
    printf "OVERWRITE=%s\n" "$(resolve_conflict_name "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir overwrite)"
    printf "SKIP=%s\n" "$(resolve_conflict_name "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir skip)"
  ')"
  assert_output_contains "${output}" 'DIR_EXISTS=yes' 'export-conflict target_exists dir'
  assert_output_contains "${output}" 'MCWORLD_EXISTS=yes' 'export-conflict target_exists mcworld'
  assert_output_contains "${output}" 'COPY_DIR=Arnis World 1 (copy 2)' 'export-conflict generate_copy_name dir'
  assert_output_contains "${output}" 'COPY_FILE=Pack (copy 2)' 'export-conflict generate_copy_name mcworld'
  assert_output_contains "${output}" 'ASK_DEFAULT=Arnis World 1 (copy 2)' 'export-conflict ask defaults to copy in non-interactive mode'
  assert_output_contains "${output}" 'OVERWRITE=__OVERWRITE__' 'export-conflict overwrite marker'
  assert_output_contains "${output}" 'SKIP=__SKIP__' 'export-conflict skip marker'

  trap - ERR
  exit_code=0
  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" ARNIS_TMP_EXPORT_DIR="${tmp_export_dir}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-conflict.sh"
    resolve_conflict_name "${ARNIS_TMP_EXPORT_DIR}" "Arnis World 1" dir broken
  ' 2>&1)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 1 ] || die "export-conflict invalid mode: expected exit 1, got ${exit_code}"
  assert_output_contains "${output}" "Invalid conflict mode 'broken'" 'export-conflict invalid mode message'

  output="$(printf '2\n' | ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-discovery.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-conflict.sh"
    WORLD_TYPES=(dir mcworld)
    WORLD_NAMES=("Arnis World 1" "Arnis Pack.mcworld")
    interactive_select
  ' 2>/dev/null)"
  assert_output_contains "${output}" '1' 'export-conflict interactive_select returns selected index'

  rm -rf "${tmp_export_dir}"

  output="$(ARNIS_LOG_COLOR=never ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-io.sh"
    WORLD_TYPES=(dir mcworld dir)
    WORLD_NAMES=("Arnis World 1" "Arnis Pack.mcworld" "Second World")
    resolve_conflict_name() { printf "%s\n" "$2"; }
    export_world_dir() { printf "EXPORT_DIR:%s|%s|%s|%s\n" "$1" "$2" "$3" "$4"; }
    export_mcworld_file() { printf "EXPORT_FILE:%s|%s|%s\n" "$1" "$2" "$3"; }
    printf "PATH=%s\n" "$(to_docker_host_path /tmp/arnis-export)"
    printf "IDX_DIR=%s\n" "$(resolve_named_world_index "Arnis World 1")"
    printf "IDX_FILE=%s\n" "$(resolve_named_world_index "Arnis Pack")"
    export_entry_by_index 0 /tmp/out ask
    export_entry_by_index 1 /tmp/out ask
  ')"
  path_line="$(printf '%s\n' "${output}" | grep '^PATH=' | head -n 1 || true)"
  [ -n "${path_line}" ] || die 'export-io to_docker_host_path did not emit a PATH= line'
  case "$(uname -s 2>/dev/null || printf unknown)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      case "${path_line}" in
        PATH=[A-Za-z]:/*|PATH=[A-Za-z]:\\*) ;;
        *) die "export-io to_docker_host_path expected a Windows-style host path, got '${path_line}'" ;;
      esac
      ;;
    *)
      [ "${path_line}" = 'PATH=/tmp/arnis-export' ] || die "export-io to_docker_host_path passthrough mismatch: ${path_line}"
      ;;
  esac
  assert_output_contains "${output}" 'IDX_DIR=0' 'export-io resolve_named_world_index exact dir'
  assert_output_contains "${output}" 'IDX_FILE=1' 'export-io resolve_named_world_index mcworld alias'
  assert_output_contains "${output}" 'EXPORT_DIR:Arnis World 1|/tmp/out|Arnis World 1|0' 'export-io dispatches directory export'
  assert_output_contains "${output}" 'EXPORT_FILE:Arnis Pack.mcworld|/tmp/out|Arnis Pack.mcworld' 'export-io dispatches mcworld export'
  assert_output_contains "${output}" '[OK] Exported world directory to: /tmp/out/Arnis World 1' 'export-io success log for directory'
  assert_output_contains "${output}" '[OK] Exported .mcworld package to: /tmp/out/Arnis Pack.mcworld' 'export-io success log for mcworld'

  trap - ERR
  exit_code=0
  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-io.sh"
    WORLD_TYPES=(dir mcworld)
    WORLD_NAMES=("Same" "Same.mcworld")
    resolve_named_world_index Same
  ' 2>&1)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 1 ] || die "export-io ambiguous name: expected exit 1, got ${exit_code}"
  assert_output_contains "${output}" "World name 'Same' is ambiguous" 'export-io ambiguous world name message'

  trap - ERR
  exit_code=0
  output="$(ARNIS_UNIT_ROOT="${REPO_ROOT}" bash -c '
    source "${ARNIS_UNIT_ROOT}/scripts/shared/logger.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/shared/common.sh"
    source "${ARNIS_UNIT_ROOT}/scripts/docker/shared/export-io.sh"
    WORLD_TYPES=(zip)
    WORLD_NAMES=("bad")
    export_entry_by_index 0 /tmp/out ask
  ' 2>&1)" || exit_code=$?
  trap 'handle_unexpected_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
  [ "${exit_code}" -eq 1 ] || die "export-io unsupported type: expected exit 1, got ${exit_code}"
  assert_output_contains "${output}" "Unsupported world type 'zip'" 'export-io unsupported type message'
}