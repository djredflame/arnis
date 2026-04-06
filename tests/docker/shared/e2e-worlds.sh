#!/usr/bin/env bash

[ "${ARNIS_TEST_E2E_WORLDS_LOADED:-0}" = "1" ] && return 0
ARNIS_TEST_E2E_WORLDS_LOADED=1

e2e_count_generated_worlds() {
  local base_dir="$1"

  run_compose run --rm --entrypoint sh arnis -c '
    set -eu
    base="$1"
    mkdir -p "$base"
    count=0
    for d in "$base"/Arnis\ World\ *; do
      if [ -d "$d" ]; then
        count=$((count + 1))
      fi
    done
    printf "%s\n" "$count"
  ' sh "${base_dir}"
}

e2e_get_latest_world_name() {
  local base_dir="$1"

  run_compose run --rm --entrypoint sh arnis -c '
    set -eu
    base="$1"
    mkdir -p "$base"
    latest=""
    for d in "$base"/Arnis\ World\ *; do
      if [ -d "$d" ] && [ -f "$d/level.dat" ]; then
        latest="$(basename "$d")"
      fi
    done
    [ -n "$latest" ]
    printf "%s\n" "$latest"
  ' sh "${base_dir}"
}

e2e_verify_latest_world_artifacts() {
  local base_dir="$1"
  local require_icon="${2:-0}"

  run_compose run --rm --entrypoint sh arnis -c '
    set -eu
    base="$1"
    need_icon="$2"

    latest=""
    for d in "$base"/Arnis\ World\ *; do
      if [ -d "$d" ]; then
        latest="$d"
      fi
    done

    [ -n "$latest" ]
    [ -f "$latest/level.dat" ]
    if [ "$need_icon" = "1" ]; then
      [ -f "$latest/icon.png" ]
    fi
    [ -d "$latest/region" ]
    ls "$latest"/region/*.mca >/dev/null 2>&1
  ' sh "${base_dir}" "${require_icon}"
}

e2e_verify_file_artifact() {
  local file_path="$1"

  run_compose run --rm --entrypoint sh arnis -c '
    set -eu
    file="$1"
    [ -f "$file" ]
    [ -s "$file" ]
  ' sh "${file_path}"
}

e2e_generation_input_ready() {
  local input_json="$1"

  run_compose run --rm --entrypoint sh arnis -c '
    set -eu
    file="$1"
    [ -f "$file" ]
    [ -s "$file" ]
  ' sh "${input_json}" >/dev/null 2>&1
}

e2e_run_generation_with_retry() {
  local output_dir="$1"
  local bbox="$2"
  local input_json="$3"
  local retries="$4"
  local retry_delay="$5"
  local retry_label="$6"
  local attempt=1
  local use_file_input=0

  if e2e_generation_input_ready "${input_json}"; then
    use_file_input=1
  fi

  while [ "${attempt}" -le "${retries}" ]; do
    if [ "${use_file_input}" -eq 1 ]; then
      if "${REPO_ROOT}/scripts/docker/run.sh" arnis \
        --output-dir "${output_dir}" \
        --bbox "${bbox}" \
        --file "${input_json}" \
        --interior=false \
        --roof=false \
        --land-cover=false \
        --timeout 30
      then
        return 0
      fi
    elif "${REPO_ROOT}/scripts/docker/run.sh" arnis \
      --output-dir "${output_dir}" \
      --bbox "${bbox}" \
      --save-json-file "${input_json}" \
      --interior=false \
      --roof=false \
      --land-cover=false \
      --timeout 30
    then
      return 0
    fi

    if [ "${attempt}" -ge "${retries}" ]; then
      break
    fi

    if [ "${use_file_input}" -eq 1 ]; then
      log_warn "${retry_label} (file input) generation attempt ${attempt}/${retries} failed, retrying in ${retry_delay}s..."
    else
      log_warn "${retry_label} (network fallback) generation attempt ${attempt}/${retries} failed, retrying in ${retry_delay}s..."
    fi
    sleep "${retry_delay}"
    attempt=$((attempt + 1))
  done

  return 1
}