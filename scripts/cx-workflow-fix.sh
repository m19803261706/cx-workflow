#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/cx-lib.sh"

PROJECT_ROOT="${PROJECT_ROOT:-}"
FIX_TITLE=""
FIX_SLUG=""
FEATURE_SLUG=""
RUNNER="cx"
SESSION_ID=""
PROBLEM=""
ROOT_CAUSE=""
RESOLUTION=""
VERIFICATION_COMMAND=""
VERIFICATION_RESULT="通过"
COMMIT_SHA=""
CONTENT=""
CONTENT_FILE=""
FORCE="false"

usage() {
  cat <<'EOF'
usage: cx-workflow-fix.sh --title <中文标题> [OPTIONS]

Write a shared workflow fix record and register it in project status.

OPTIONS:
  --project-root <path>         Project root
  --title <text>                Fix title
  --slug <slug>                 Stable fix slug; auto-derived if omitted
  --feature <slug>              Optional related feature slug
  --runner <cx|cc|codex>        Fix runner (default: cx)
  --session-id <id>             Optional session id for related feature ownership validation
  --problem <text>              Problem description
  --root-cause <text>           Root cause summary
  --resolution <a|b|c>          Pipe-separated resolutions
  --verification-command <txt>  Verification command summary
  --verification-result <txt>   Verification result summary
  --commit <sha>                Related commit sha
  --content <text>              Inline fix record content
  --content-file <path>         Fix record content file path
  --force                       Bypass feature lease validation
  --help                        Show this help message
EOF
}

die() {
  echo "[cx-workflow-fix] $*" >&2
  exit 1
}

now_iso() {
  if [[ -n "${CX_WORKFLOW_NOW:-}" ]]; then
    printf '%s\n' "$CX_WORKFLOW_NOW"
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-root)
        PROJECT_ROOT="$2"
        shift 2
        ;;
      --title)
        FIX_TITLE="$2"
        shift 2
        ;;
      --slug)
        FIX_SLUG="$2"
        shift 2
        ;;
      --feature)
        FEATURE_SLUG="$2"
        shift 2
        ;;
      --runner)
        RUNNER="$2"
        shift 2
        ;;
      --session-id)
        SESSION_ID="$2"
        shift 2
        ;;
      --problem)
        PROBLEM="$2"
        shift 2
        ;;
      --root-cause)
        ROOT_CAUSE="$2"
        shift 2
        ;;
      --resolution)
        RESOLUTION="$2"
        shift 2
        ;;
      --verification-command)
        VERIFICATION_COMMAND="$2"
        shift 2
        ;;
      --verification-result)
        VERIFICATION_RESULT="$2"
        shift 2
        ;;
      --commit)
        COMMIT_SHA="$2"
        shift 2
        ;;
      --content)
        CONTENT="$2"
        shift 2
        ;;
      --content-file)
        CONTENT_FILE="$2"
        shift 2
        ;;
      --force)
        FORCE="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

detect_project_root() {
  if [[ -n "$PROJECT_ROOT" ]]; then
    return
  fi

  if PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
    return
  fi

  PROJECT_ROOT=$(pwd)
}

validate_args() {
  [[ -n "$FIX_TITLE" ]] || die "missing required --title"

  case "$RUNNER" in
    cx|cc|codex) ;;
    *) die "--runner must be cx, cc, or codex" ;;
  esac

  if [[ -n "$CONTENT" && -n "$CONTENT_FILE" ]]; then
    die "use only one of --content or --content-file"
  fi
}

ensure_runtime() {
  [[ -f "$(cx_public_status_file "$PROJECT_ROOT")" ]] || die "missing 开发文档/CX工作流/状态.json"
}

slugify() {
  local title="$1"
  local normalized

  normalized=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
  if [[ -z "$normalized" ]]; then
    normalized="fix-$(printf '%s' "$title" | shasum | awk '{print $1}' | cut -c1-10)"
  fi
  printf '%s\n' "$normalized"
}

resolve_fix_slug() {
  if [[ -z "$FIX_SLUG" ]]; then
    FIX_SLUG=$(slugify "$FIX_TITLE")
  fi
}

fix_dir() {
  cx_public_fix_dir_by_title "$FIX_TITLE" "$PROJECT_ROOT"
}

fix_file() {
  printf '%s/修复记录.md\n' "$(fix_dir)"
}

project_status_file() {
  cx_public_status_file "$PROJECT_ROOT"
}

default_text() {
  local value="$1"
  local fallback="$2"
  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

pipe_to_bullets() {
  local raw="$1"
  local prefix="$2"
  local fallback="$3"
  local item=""

  if [[ -z "$raw" ]]; then
    printf '%s %s\n' "$prefix" "$fallback"
    return
  fi

  IFS='|' read -r -a items <<< "$raw"
  for item in "${items[@]}"; do
    printf '%s %s\n' "$prefix" "$item"
  done
}

load_fix_content() {
  if [[ -n "$CONTENT_FILE" ]]; then
    [[ -f "$CONTENT_FILE" ]] || die "fix content file not found: $CONTENT_FILE"
    cat "$CONTENT_FILE"
    return
  fi

  if [[ -n "$CONTENT" ]]; then
    printf '%s\n' "$CONTENT"
    return
  fi

  {
    printf '# 修复记录：%s\n\n' "$FIX_TITLE"
    printf -- '- 保存路径：`开发文档/CX工作流/修复/%s/修复记录.md`\n' "$FIX_TITLE"
    printf -- '- 稳定 slug：`%s`\n\n' "$FIX_SLUG"

    printf '## 问题描述\n\n'
    printf '%s\n\n' "$(default_text "$PROBLEM" "待补充问题现象、影响范围和复现条件。")"

    printf '## 根因分析\n\n'
    printf '%s\n\n' "$(default_text "$ROOT_CAUSE" "待补充根因分析。")"

    printf '## 修复方案\n\n'
    pipe_to_bullets "$RESOLUTION" "-" "待补充修复方案"
    printf '\n'

    printf '## 验证结果\n\n'
    printf -- '- 命令：%s\n' "$(default_text "$VERIFICATION_COMMAND" "最相关验证已通过")"
    printf -- '- 结果：%s\n\n' "$VERIFICATION_RESULT"

    printf '## 提交记录\n\n'
    printf -- '- commit: `%s`\n' "$(default_text "$COMMIT_SHA" "待补充")"
    printf -- '- message: `fix(scope): description [cx-fix:%s]`\n\n' "$FIX_SLUG"

    printf '## 后续说明\n\n'
    printf -- '- 是否还有风险：待补充\n'
    printf -- '- 是否需要继续跟踪：待补充\n'
  }
}

ensure_feature_access() {
  local lease_session
  if [[ -z "$FEATURE_SLUG" ]]; then
    return
  fi

  [[ -f "$(cx_core_project_file "$PROJECT_ROOT")" ]] || die "missing .cx/core/projects/project.json for related feature validation"
  jq -e --arg slug "$FEATURE_SLUG" '.features[$slug]' "$(cx_core_project_file "$PROJECT_ROOT")" >/dev/null \
    || die "related feature $FEATURE_SLUG is not registered"

  lease_session=$(jq -r --arg slug "$FEATURE_SLUG" '.features[$slug].lease_session_id // empty' "$(cx_core_project_file "$PROJECT_ROOT")")
  if [[ "$FORCE" != "true" && -n "$lease_session" ]]; then
    [[ -n "$SESSION_ID" ]] || die "session id is required when related feature $FEATURE_SLUG has an active lease"
    [[ "$lease_session" == "$SESSION_ID" ]] || die "related feature $FEATURE_SLUG is currently leased by $lease_session, not $SESSION_ID"
  fi
}

write_fix_doc() {
  mkdir -p "$(fix_dir)"
  load_fix_content > "$(fix_file)"
}

update_project_status() {
  local now="$1"
  jq \
    --arg slug "$FIX_SLUG" \
    --arg title "$FIX_TITLE" \
    --arg path "修复/$FIX_TITLE" \
    --arg now "$now" \
    '
      .last_updated = $now
      | .fixes[$slug] = {
          title: $title,
          path: $path,
          last_updated: $now
        }
    ' "$(project_status_file)" > "$(project_status_file).tmp"
  mv "$(project_status_file).tmp" "$(project_status_file)"
}

main() {
  parse_args "$@"
  detect_project_root
  validate_args
  ensure_runtime
  resolve_fix_slug
  ensure_feature_access

  local now
  now=$(now_iso)
  write_fix_doc
  update_project_status "$now"

  printf 'fix_slug=%s\n' "$FIX_SLUG"
  printf 'fix_title=%s\n' "$FIX_TITLE"
  printf 'related_feature=%s\n' "$FEATURE_SLUG"
}

main "$@"
