#!/bin/bash
# cx-lib.sh — 可被其他 cx 脚本 source 的公共函数库
# 用法: source "$(dirname "${BASH_SOURCE[0]}")/cx-lib.sh"

cx_detect_project_root() {
  if [[ -n "${PROJECT_ROOT:-}" ]]; then
    printf '%s\n' "$PROJECT_ROOT"
    return 0
  fi

  git rev-parse --show-toplevel 2>/dev/null || pwd
}

cx_legacy_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/.claude/cx\n' "$project_root"
}

cx_machine_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/.cx\n' "$project_root"
}

cx_docs_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/开发文档/CX工作流\n' "$project_root"
}

cx_public_config_file() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/配置.json\n' "$(cx_docs_root "$project_root")"
}

cx_public_status_file() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/状态.json\n' "$(cx_docs_root "$project_root")"
}

cx_public_feature_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/功能\n' "$(cx_docs_root "$project_root")"
}

cx_public_fix_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/修复\n' "$(cx_docs_root "$project_root")"
}

cx_core_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/core\n' "$(cx_machine_root "$project_root")"
}

cx_runtime_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/runtime\n' "$(cx_machine_root "$project_root")"
}

cx_runner_runtime_root() {
  local runner="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  printf '%s/%s\n' "$(cx_runtime_root "$project_root")" "$runner"
}

cx_core_projects_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/projects\n' "$(cx_core_root "$project_root")"
}

cx_core_features_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/features\n' "$(cx_core_root "$project_root")"
}

cx_core_feature_registry_file() {
  local slug="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  printf '%s/%s.json\n' "$(cx_core_features_root "$project_root")" "$slug"
}

cx_core_sessions_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/sessions\n' "$(cx_core_root "$project_root")"
}

cx_core_session_file() {
  local session_id="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  printf '%s/%s.json\n' "$(cx_core_sessions_root "$project_root")" "$session_id"
}

cx_core_handoffs_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/handoffs\n' "$(cx_core_root "$project_root")"
}

cx_core_worktrees_root() {
  local project_root="${1:-$(cx_detect_project_root)}"
  printf '%s/worktrees\n' "$(cx_core_root "$project_root")"
}

cx_core_worktree_file() {
  local slug="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  printf '%s/%s.json\n' "$(cx_core_worktrees_root "$project_root")" "$slug"
}

cx_public_feature_dir_by_title() {
  local title="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  printf '%s/%s\n' "$(cx_public_feature_root "$project_root")" "$title"
}

cx_public_fix_dir_by_title() {
  local title="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  printf '%s/%s\n' "$(cx_public_fix_root "$project_root")" "$title"
}

cx_legacy_runtime_exists() {
  local project_root="${1:-$(cx_detect_project_root)}"
  [[ -f "$(cx_legacy_root "$project_root")/配置.json" && -f "$(cx_legacy_root "$project_root")/状态.json" ]]
}

cx_public_runtime_exists() {
  local project_root="${1:-$(cx_detect_project_root)}"
  [[ -f "$(cx_public_config_file "$project_root")" && -f "$(cx_public_status_file "$project_root")" ]]
}

cx_require_jq() {
  command -v jq >/dev/null 2>&1
}

cx_resolve_path() {
  local path="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$project_root" "$path"
  fi
}

cx_relative_path() {
  local path="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  if [[ "$path" = "$project_root/"* ]]; then
    printf '%s\n' "${path#"$project_root/"}"
  else
    printf '%s\n' "$path"
  fi
}

cx_core_feature_file() {
  local slug="$1"
  local project_root="${2:-$(cx_detect_project_root)}"

  [[ -n "$slug" ]] || return 0

  if [[ -f "$(cx_core_feature_registry_file "$slug" "$project_root")" ]]; then
    cx_core_feature_registry_file "$slug" "$project_root"
    return 0
  fi

  if [[ -f "$(cx_legacy_root "$project_root")/core/features/$slug.json" ]]; then
    printf '%s/core/features/%s.json\n' "$(cx_legacy_root "$project_root")" "$slug"
  fi
}

cx_feature_title_from_slug() {
  local slug="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  local feature_file=""
  local public_status=""
  local title=""

  [[ -n "$slug" ]] || return 0

  feature_file=$(cx_core_feature_file "$slug" "$project_root")
  if [[ -n "$feature_file" && -f "$feature_file" ]]; then
    title=$(jq -r '.title // empty' "$feature_file" 2>/dev/null || true)
    if [[ -n "$title" ]]; then
      printf '%s\n' "$title"
      return 0
    fi
  fi

  public_status="$(cx_public_status_file "$project_root")"
  if [[ -f "$public_status" ]]; then
    title=$(jq -r --arg slug "$slug" '.features[$slug].title // empty' "$public_status" 2>/dev/null || true)
    if [[ -n "$title" ]]; then
      printf '%s\n' "$title"
      return 0
    fi
  fi

  if [[ -f "$(cx_legacy_root "$project_root")/状态.json" ]]; then
    title=$(jq -r --arg slug "$slug" '.features[$slug].title // empty' "$(cx_legacy_root "$project_root")/状态.json" 2>/dev/null || true)
    if [[ -n "$title" ]]; then
      printf '%s\n' "$title"
      return 0
    fi
  fi

  printf ''
}

cx_feature_dir_from_slug() {
  local slug="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  local title=""

  [[ -n "$slug" ]] || return 0

  title=$(cx_feature_title_from_slug "$slug" "$project_root")
  if [[ -n "$title" ]]; then
    cx_public_feature_dir_by_title "$title" "$project_root"
    return 0
  fi

  printf ''
}

cx_feature_status_file_from_slug() {
  local slug="$1"
  local project_root="${2:-$(cx_detect_project_root)}"
  local feature_dir=""

  feature_dir=$(cx_feature_dir_from_slug "$slug" "$project_root")
  [[ -n "$feature_dir" ]] || return 0
  printf '%s/状态.json\n' "$feature_dir"
}

cx_core_project_file() {
  local project_root="${1:-$(cx_detect_project_root)}"
  local candidate=""
  local project_dir=""
  local matches=()

  candidate="$(cx_core_root "$project_root")/project.json"
  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  project_dir="$(cx_core_projects_root "$project_root")"
  matches=("$project_dir"/*.json)
  if [[ ${#matches[@]} -eq 1 && -f "${matches[0]}" ]]; then
    printf '%s\n' "${matches[0]}"
    return 0
  fi

  if [[ -f "$(cx_legacy_root "$project_root")/core/project.json" ]]; then
    printf '%s/core/project.json\n' "$(cx_legacy_root "$project_root")"
    return 0
  fi

  matches=("$(cx_legacy_root "$project_root")/core/projects"/*.json)
  if [[ ${#matches[@]} -eq 1 && -f "${matches[0]}" ]]; then
    printf '%s\n' "${matches[0]}"
  fi
}

cx_runner_runtime_file() {
  local runner="$1"
  local filename="$2"
  local project_root="${3:-$(cx_detect_project_root)}"
  printf '%s/%s\n' "$(cx_runner_runtime_root "$runner" "$project_root")" "$filename"
}

cx_core_runtime_exists() {
  local project_root="${1:-$(cx_detect_project_root)}"
  local project_file=""
  project_file=$(cx_core_project_file "$project_root")
  [[ -n "$project_file" && -f "$project_file" ]]
}

cx_has_runtime() {
  local project_root="${1:-$(cx_detect_project_root)}"
  cx_core_runtime_exists "$project_root" || cx_public_runtime_exists "$project_root" || cx_legacy_runtime_exists "$project_root"
}

cx_runtime_mode() {
  local project_root="${1:-$(cx_detect_project_root)}"
  if cx_core_runtime_exists "$project_root"; then
    printf 'core\n'
    return 0
  fi

  if cx_public_runtime_exists "$project_root"; then
    printf 'public\n'
    return 0
  fi

  if cx_legacy_runtime_exists "$project_root"; then
    printf 'legacy\n'
  fi
}

# 从当前 worktree 分支名推导 feature slug
# 分支命名约定: feature/{slug}, cc/{slug}, codex/{slug}
# 返回 slug 或空字符串
detect_feature_from_branch() {
  local repo_root="${1:-.}"
  local repo_root_abs=""
  local git_root=""
  local branch

  repo_root_abs=$(cd "$repo_root" 2>/dev/null && pwd -P) || {
    printf ''
    return 0
  }

  git_root=$(git -C "$repo_root_abs" rev-parse --show-toplevel 2>/dev/null || true)
  if [[ -z "$git_root" ]]; then
    printf ''
    return 0
  fi

  git_root=$(cd "$git_root" 2>/dev/null && pwd -P) || {
    printf ''
    return 0
  }

  if [[ "$git_root" != "$repo_root_abs" ]]; then
    printf ''
    return 0
  fi

  branch=$(git -C "$repo_root_abs" branch --show-current 2>/dev/null || true)

  case "$branch" in
    feature/*)  printf '%s\n' "${branch#feature/}" ;;
    cc/*)       printf '%s\n' "${branch#cc/}" ;;
    codex/*)    printf '%s\n' "${branch#codex/}" ;;
    *)          printf '' ;;
  esac
}

# 推导当前 feature slug：先看 worktree 分支，fallback 到 current_feature
# 参数: $1 = project_root
resolve_current_feature() {
  local project_root="${1:-$(cx_detect_project_root)}"
  local slug
  local project_file=""

  slug=$(detect_feature_from_branch "$project_root")
  if [[ -n "$slug" ]]; then
    printf '%s\n' "$slug"
    return 0
  fi

  if [[ -f "$(cx_public_status_file "$project_root")" ]]; then
    slug=$(jq -r '.current_feature // empty' "$(cx_public_status_file "$project_root")" 2>/dev/null)
    if [[ -n "$slug" ]]; then
      printf '%s\n' "$slug"
      return 0
    fi
  fi

  project_file=$(cx_core_project_file "$project_root")
  if [[ -n "$project_file" && -f "$project_file" ]]; then
    slug=$(jq -r '.current_feature // empty' "$project_file" 2>/dev/null)
    if [[ -n "$slug" ]]; then
      printf '%s\n' "$slug"
      return 0
    fi
  fi

  if [[ -f "$(cx_legacy_root "$project_root")/状态.json" ]]; then
    slug=$(jq -r '.current_feature // empty' "$(cx_legacy_root "$project_root")/状态.json" 2>/dev/null)
    if [[ -n "$slug" ]]; then
      printf '%s\n' "$slug"
      return 0
    fi
  fi

  printf ''
}
