#!/bin/bash

cx_project_root() {
  if [[ -n "${PROJECT_ROOT:-}" ]]; then
    printf '%s\n' "$PROJECT_ROOT"
    return 0
  fi

  git rev-parse --show-toplevel 2>/dev/null || pwd
}

cx_dir() {
  printf '%s/.claude/cx\n' "$(cx_project_root)"
}

cx_config_file() {
  printf '%s/配置.json\n' "$(cx_dir)"
}

cx_project_status_file() {
  printf '%s/状态.json\n' "$(cx_dir)"
}

cx_has_runtime() {
  [[ -f "$(cx_config_file)" && -f "$(cx_project_status_file)" ]]
}

cx_require_jq() {
  command -v jq >/dev/null 2>&1
}

cx_current_feature_slug() {
  if ! cx_has_runtime || ! cx_require_jq; then
    return 0
  fi

  jq -r '.current_feature // empty' "$(cx_config_file)" 2>/dev/null
}

cx_feature_relative_path() {
  local slug="${1:-}"

  [[ -n "$slug" ]] || return 0
  jq -r --arg slug "$slug" '.features[$slug].path // empty' "$(cx_project_status_file)" 2>/dev/null
}

cx_feature_dir() {
  local slug="${1:-}"
  local relative_path=""

  relative_path=$(cx_feature_relative_path "$slug")
  [[ -n "$relative_path" ]] || return 0

  printf '%s/%s\n' "$(cx_dir)" "$relative_path"
}

cx_feature_status_file() {
  local slug="${1:-}"
  local feature_dir=""

  feature_dir=$(cx_feature_dir "$slug")
  [[ -n "$feature_dir" ]] || return 0

  printf '%s/状态.json\n' "$feature_dir"
}

cx_feature_title() {
  local slug="${1:-}"
  local status_file=""

  status_file=$(cx_feature_status_file "$slug")
  if [[ -n "$status_file" && -f "$status_file" ]]; then
    jq -r '.feature // empty' "$status_file" 2>/dev/null
    return 0
  fi

  jq -r --arg slug "$slug" '.features[$slug].title // empty' "$(cx_project_status_file)" 2>/dev/null
}
