#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../scripts/cx-lib.sh"

cx_runner_name() {
  printf 'cc\n'
}

cx_project_root() {
  cx_detect_project_root
}

cx_dir() {
  cx_docs_root "$(cx_project_root)"
}

cx_core_dir() {
  cx_core_root "$(cx_project_root)"
}

cx_config_file() {
  cx_public_config_file "$(cx_project_root)"
}

cx_project_status_file() {
  cx_public_status_file "$(cx_project_root)"
}

cx_runtime_dir() {
  cx_runner_runtime_root "$(cx_runner_name)" "$(cx_project_root)"
}

cx_ensure_runtime_dir() {
  mkdir -p "$(cx_runtime_dir)"
}

cx_current_feature_slug() {
  local project_root
  project_root=$(cx_project_root)

  if ! cx_has_runtime "$project_root" || ! cx_require_jq; then
    return 0
  fi

  resolve_current_feature "$project_root"
}

cx_feature_relative_path() {
  local slug="${1:-}"
  local project_root

  [[ -n "$slug" ]] || return 0
  project_root=$(cx_project_root)

  if [[ -f "$(cx_project_status_file)" ]]; then
    jq -r --arg slug "$slug" '.features[$slug].path // empty' "$(cx_project_status_file)" 2>/dev/null
    return 0
  fi

  if [[ -f "$(cx_legacy_root "$project_root")/状态.json" ]]; then
    jq -r --arg slug "$slug" '.features[$slug].path // empty' "$(cx_legacy_root "$project_root")/状态.json" 2>/dev/null
  fi
}

cx_feature_dir() {
  local slug="${1:-}"
  cx_feature_dir_from_slug "$slug" "$(cx_project_root)"
}

cx_feature_status_file() {
  local slug="${1:-}"
  cx_feature_status_file_from_slug "$slug" "$(cx_project_root)"
}

cx_feature_title() {
  local slug="${1:-}"
  cx_feature_title_from_slug "$slug" "$(cx_project_root)"
}

cx_feature_stage() {
  local slug="${1:-}"
  local mode=""
  local feature_file=""
  local status_file=""

  mode=$(cx_runtime_mode "$(cx_project_root)")
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
      jq -r '.lifecycle.stage // "draft"' "$feature_file" 2>/dev/null
      ;;
    public|legacy)
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

  mode=$(cx_runtime_mode "$(cx_project_root)")
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
      jq -r '(.tasks // []) | length' "$feature_file" 2>/dev/null
      ;;
    public|legacy)
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

  mode=$(cx_runtime_mode "$(cx_project_root)")
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
      jq -r '[.tasks[]? | select(.status == "completed")] | length' "$feature_file" 2>/dev/null
      ;;
    public|legacy)
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

  mode=$(cx_runtime_mode "$(cx_project_root)")
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
      jq -r 'first((.tasks // [])[] | select(.status == "in_progress" or .status == "claimed") | "task-\(.id) \(.title)") // empty' "$feature_file" 2>/dev/null
      ;;
    public|legacy)
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

  mode=$(cx_runtime_mode "$(cx_project_root)")
  case "$mode" in
    core)
      feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
      stage=$(jq -r '.lifecycle.stage // "draft"' "$feature_file" 2>/dev/null)
      if [[ "$stage" == "blocked" ]]; then
        jq -r '.lifecycle.blocked_reason // empty' "$feature_file" 2>/dev/null
      fi
      ;;
    public|legacy)
      status_file=$(cx_feature_status_file "$slug")
      jq -r '.blocked.reason_type // empty' "$status_file" 2>/dev/null
      ;;
  esac
}

cx_feature_block_message() {
  local slug="${1:-}"
  local mode=""
  local status_file=""

  mode=$(cx_runtime_mode "$(cx_project_root)")
  case "$mode" in
    core)
      printf ''
      ;;
    public|legacy)
      status_file=$(cx_feature_status_file "$slug")
      jq -r '.blocked.message // empty' "$status_file" 2>/dev/null
      ;;
  esac
}

cx_feature_owner_runner() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode "$(cx_project_root)")" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
  jq -r '.execution_owner.runner // .lease.runner // empty' "$feature_file" 2>/dev/null
}

cx_feature_owner_session() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode "$(cx_project_root)")" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
  jq -r '.execution_owner.session_id // .lease.session_id // empty' "$feature_file" 2>/dev/null
}

cx_feature_lease_session() {
  local slug="${1:-}"
  local lease_session=""
  local feature_file=""
  local project_file=""

  [[ "$(cx_runtime_mode "$(cx_project_root)")" == "core" ]] || return 0

  project_file=$(cx_core_project_file "$(cx_project_root)")
  lease_session=$(jq -r --arg slug "$slug" '.features[$slug].lease_session_id // empty' "$project_file" 2>/dev/null)
  if [[ -n "$lease_session" ]]; then
    printf '%s\n' "$lease_session"
    return 0
  fi

  feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
  if [[ -n "$feature_file" && -f "$feature_file" ]]; then
    jq -r '.lease.session_id // empty' "$feature_file" 2>/dev/null
  fi
}

cx_feature_lease_expires_at() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode "$(cx_project_root)")" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
  jq -r '.lease.expires_at // empty' "$feature_file" 2>/dev/null
}

cx_feature_worktree_path() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode "$(cx_project_root)")" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
  jq -r '.worktree.worktree_path // empty' "$feature_file" 2>/dev/null
}

cx_feature_worktree_branch() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode "$(cx_project_root)")" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
  jq -r '.worktree.branch // empty' "$feature_file" 2>/dev/null
}

cx_feature_latest_handoff_record() {
  local slug="${1:-}"
  local feature_file=""

  [[ "$(cx_runtime_mode "$(cx_project_root)")" == "core" ]] || return 0
  feature_file=$(cx_core_feature_file "$slug" "$(cx_project_root)")
  jq -r '.handoffs[-1].record_path // empty' "$feature_file" 2>/dev/null
}

cx_feature_has_foreign_owner() {
  local slug="${1:-}"
  local owner_runner=""

  [[ "$(cx_runtime_mode "$(cx_project_root)")" == "core" ]] || return 1
  owner_runner=$(cx_feature_owner_runner "$slug")
  [[ -n "$owner_runner" && "$owner_runner" != "$(cx_runner_name)" ]]
}

cx_feature_lease_is_stale() {
  local slug="${1:-}"
  local expires_at=""

  [[ "$(cx_runtime_mode "$(cx_project_root)")" == "core" ]] || return 1
  expires_at=$(cx_feature_lease_expires_at "$slug")
  [[ -n "$expires_at" ]] || return 1

  jq -nr --arg expires_at "$expires_at" 'now > ($expires_at | fromdateiso8601)' | grep -q true
}
