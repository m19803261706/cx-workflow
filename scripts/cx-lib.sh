#!/bin/bash
# cx-lib.sh — 可被其他 cx 脚本 source 的公共函数库
# 用法: source "$(dirname "${BASH_SOURCE[0]}")/cx-lib.sh"

# 从当前 worktree 分支名推导 feature slug
# 分支命名约定: feature/{slug}, cc/{slug}, codex/{slug}
# 返回 slug 或空字符串
detect_feature_from_branch() {
  local branch
  branch=$(git branch --show-current 2>/dev/null || true)

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
  local project_root="${1:-.}"
  local slug

  # Priority 1: worktree 分支名
  slug=$(detect_feature_from_branch)
  if [[ -n "$slug" ]]; then
    printf '%s\n' "$slug"
    return
  fi

  # Priority 2: 状态.json current_feature (deprecated hint)
  if [[ -f "$project_root/.claude/cx/状态.json" ]]; then
    slug=$(jq -r '.current_feature // empty' "$project_root/.claude/cx/状态.json" 2>/dev/null)
    if [[ -n "$slug" ]]; then
      printf '%s\n' "$slug"
      return
    fi
  fi

  # Priority 3: core project.json current_feature (deprecated hint)
  local project_file="$project_root/.claude/cx/core/projects/project.json"
  if [[ -f "$project_file" ]]; then
    slug=$(jq -r '.current_feature // empty' "$project_file" 2>/dev/null)
    if [[ -n "$slug" ]]; then
      printf '%s\n' "$slug"
      return
    fi
  fi

  printf ''
}
