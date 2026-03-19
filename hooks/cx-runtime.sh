#!/bin/bash

cx_runner_name() {
  printf 'cc\n'
}

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

cx_core_dir() {
  printf '%s/core\n' "$(cx_dir)"
}

cx_config_file() {
  printf '%s/配置.json\n' "$(cx_dir)"
}

cx_project_status_file() {
  printf '%s/状态.json\n' "$(cx_dir)"
}

cx_core_project_file() {
  local candidate=""
  local project_dir=""
  local matches=()

  candidate="$(cx_core_dir)/project.json"
  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  project_dir="$(cx_core_dir)/projects"
  matches=("$project_dir"/*.json)
  if [[ ${#matches[@]} -eq 1 && -f "${matches[0]}" ]]; then
    printf '%s\n' "${matches[0]}"
  fi
}

cx_core_has_runtime() {
  local project_file=""
  project_file=$(cx_core_project_file)
  [[ -n "$project_file" && -f "$project_file" ]]
}

cx_legacy_has_runtime() {
  [[ -f "$(cx_config_file)" && -f "$(cx_project_status_file)" ]]
}

cx_has_runtime() {
  cx_core_has_runtime || cx_legacy_has_runtime
}

cx_runtime_mode() {
  if cx_core_has_runtime; then
    printf 'core\n'
    return 0
  fi

  if cx_legacy_has_runtime; then
    printf 'legacy\n'
  fi
}

cx_require_jq() {
  command -v jq >/dev/null 2>&1
}

cx_runtime_dir() {
  printf '%s/runtime/%s\n' "$(cx_dir)" "$(cx_runner_name)"
}

cx_ensure_runtime_dir() {
  mkdir -p "$(cx_runtime_dir)"
}

cx_resolve_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$(cx_project_root)" "$path"
  fi
}

cx_current_feature_slug() {
  local mode=""

  if ! cx_has_runtime || ! cx_require_jq; then
    return 0
  fi

  mode=$(cx_runtime_mode)
  case "$mode" in
    core)
      jq -r '.current_feature // empty' "$(cx_core_project_file)" 2>/dev/null
      ;;
    legacy)
      jq -r '.current_feature // empty' "$(cx_config_file)" 2>/dev/null
      ;;
  esac
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

cx_core_feature_file() {
  local slug="${1:-}"
  local relative_path=""

  [[ -n "$slug" ]] || return 0
  relative_path=$(jq -r --arg slug "$slug" '.features[$slug].path // empty' "$(cx_core_project_file)" 2>/dev/null)
  [[ -n "$relative_path" ]] || return 0

  cx_resolve_path "$relative_path"
}

cx_feature_title() {
  local slug="${1:-}"
  local mode=""
  local feature_file=""
  local status_file=""

  mode=$(cx_runtime_mode)
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug")
      if [[ -n "$feature_file" && -f "$feature_file" ]]; then
        jq -r '.title // empty' "$feature_file" 2>/dev/null
        return 0
      fi
      jq -r --arg slug "$slug" '.features[$slug].title // empty' "$(cx_core_project_file)" 2>/dev/null
      ;;
    legacy)
      status_file=$(cx_feature_status_file "$slug")
      if [[ -n "$status_file" && -f "$status_file" ]]; then
        jq -r '.feature // empty' "$status_file" 2>/dev/null
        return 0
      fi
      jq -r --arg slug "$slug" '.features[$slug].title // empty' "$(cx_project_status_file)" 2>/dev/null
      ;;
  esac
}

cx_feature_stage() {
  local slug="${1:-}"
  local mode=""
  local feature_file=""
  local status_file=""

  mode=$(cx_runtime_mode)
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug")
      jq -r '.lifecycle.stage // "draft"' "$feature_file" 2>/dev/null
      ;;
    legacy)
      status_file=$(cx_feature_status_file "$slug")
      jq -r '.status // "drafting"' "$status_file" 2>/dev/null
      ;;
  esac
}

cx_feature_total_tasks() {
  local slug="${1:-}"
  local mode=""
  local feature_file=""
  local status_file=""

  mode=$(cx_runtime_mode)
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug")
      jq -r '(.tasks // []) | length' "$feature_file" 2>/dev/null
      ;;
    legacy)
      status_file=$(cx_feature_status_file "$slug")
      jq -r '.total // 0' "$status_file" 2>/dev/null
      ;;
  esac
}

cx_feature_completed_tasks() {
  local slug="${1:-}"
  local mode=""
  local feature_file=""
  local status_file=""

  mode=$(cx_runtime_mode)
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug")
      jq -r '[.tasks[]? | select(.status == "completed")] | length' "$feature_file" 2>/dev/null
      ;;
    legacy)
      status_file=$(cx_feature_status_file "$slug")
      jq -r '.completed // 0' "$status_file" 2>/dev/null
      ;;
  esac
}

cx_feature_current_task() {
  local slug="${1:-}"
  local mode=""
  local feature_file=""
  local status_file=""

  mode=$(cx_runtime_mode)
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug")
      jq -r 'first((.tasks // [])[] | select(.status == "in_progress" or .status == "claimed") | "task-\(.id) \(.title)") // empty' "$feature_file" 2>/dev/null
      ;;
    legacy)
      status_file=$(cx_feature_status_file "$slug")
      jq -r 'first(.tasks[] | select(.status == "in_progress") | "task-\(.number) \(.title)") // empty' "$status_file" 2>/dev/null
      ;;
  esac
}

cx_feature_block_reason() {
  local slug="${1:-}"
  local mode=""
  local feature_file=""
  local status_file=""
  local stage=""

  mode=$(cx_runtime_mode)
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug")
      stage=$(jq -r '.lifecycle.stage // "draft"' "$feature_file" 2>/dev/null)
      if [[ "$stage" == "blocked" ]]; then
        jq -r '.lifecycle.blocked_reason // empty' "$feature_file" 2>/dev/null
      fi
      ;;
    legacy)
      status_file=$(cx_feature_status_file "$slug")
      jq -r '.blocked.reason_type // empty' "$status_file" 2>/dev/null
      ;;
  esac
}

cx_feature_block_message() {
  local slug="${1:-}"
  local mode=""
  local status_file=""

  mode=$(cx_runtime_mode)
  case "$mode" in
    core)
      printf ''
      ;;
    legacy)
      status_file=$(cx_feature_status_file "$slug")
      jq -r '.blocked.message // empty' "$status_file" 2>/dev/null
      ;;
  esac
}

cx_feature_owner_runner() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode)" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug")
  jq -r '.execution_owner.runner // .lease.runner // empty' "$feature_file" 2>/dev/null
}

cx_feature_owner_session() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode)" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug")
  jq -r '.execution_owner.session_id // .lease.session_id // empty' "$feature_file" 2>/dev/null
}

cx_feature_lease_session() {
  local slug="${1:-}"
  local lease_session=""
  local feature_file=""

  [[ "$(cx_runtime_mode)" == "core" ]] || return 0
  lease_session=$(jq -r --arg slug "$slug" '.features[$slug].lease_session_id // empty' "$(cx_core_project_file)" 2>/dev/null)
  if [[ -n "$lease_session" ]]; then
    printf '%s\n' "$lease_session"
    return 0
  fi

  feature_file=$(cx_core_feature_file "$slug")
  if [[ -n "$feature_file" && -f "$feature_file" ]]; then
    jq -r '.lease.session_id // empty' "$feature_file" 2>/dev/null
  fi
}

cx_feature_lease_expires_at() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode)" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug")
  jq -r '.lease.expires_at // empty' "$feature_file" 2>/dev/null
}

cx_feature_worktree_path() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode)" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug")
  jq -r '.worktree.worktree_path // empty' "$feature_file" 2>/dev/null
}

cx_feature_worktree_branch() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode)" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug")
  jq -r '.worktree.branch // empty' "$feature_file" 2>/dev/null
}

cx_feature_latest_handoff_record() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode)" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug")
  jq -r '.handoffs[-1].record_path // empty' "$feature_file" 2>/dev/null
}

cx_feature_has_foreign_owner() {
  local slug="${1:-}"
  local owner_runner=""

  [[ "$(cx_runtime_mode)" == "core" ]] || return 1
  owner_runner=$(cx_feature_owner_runner "$slug")
  [[ -n "$owner_runner" && "$owner_runner" != "$(cx_runner_name)" ]]
}

cx_feature_lease_is_stale() {
  local slug="${1:-}"
  local expires_at=""

  [[ "$(cx_runtime_mode)" == "core" ]] || return 1
  expires_at=$(cx_feature_lease_expires_at "$slug")
  [[ -n "$expires_at" ]] || return 1

  jq -nr --arg expires_at "$expires_at" 'now > ($expires_at | fromdateiso8601)' | grep -q true
}
