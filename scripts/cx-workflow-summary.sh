#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-}"
FEATURE_SLUG=""
FEATURE_TITLE=""
RUNNER="cx"
SESSION_ID=""
CONTENT=""
CONTENT_FILE=""
DELIVERABLES=""
DESIGN_CHANGES=""
TEST_COMMAND=""
TEST_RESULT="通过"
REVIEW_RESULT="通过"
DECISION_BASIS=""
FORCE="false"

usage() {
  cat <<'EOF'
usage: cx-workflow-summary.sh --feature <slug> [OPTIONS]

Write the shared workflow summary doc and archive a completed feature.

OPTIONS:
  --project-root <path>         Project root
  --feature <slug>              Feature slug
  --title <text>                Optional Chinese title override
  --runner <cx|cc|codex>        Summary runner (default: cx)
  --session-id <id>             Optional session id used to release the active claim
  --content <text>              Inline summary content
  --content-file <path>         Summary content file path
  --deliverables <a|b|c>        Pipe-separated deliverables
  --design-changes <text>       Design change summary
  --test-command <text>         Validation command summary
  --test-result <text>          Validation result summary
  --review-result <text>        Review result summary
  --decision-basis <text>       Summary phase decision basis
  --force                       Allow summary on non-completed features
  --help                        Show this help message
EOF
}

die() {
  echo "[cx-workflow-summary] $*" >&2
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
      --feature)
        FEATURE_SLUG="$2"
        shift 2
        ;;
      --title)
        FEATURE_TITLE="$2"
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
      --content)
        CONTENT="$2"
        shift 2
        ;;
      --content-file)
        CONTENT_FILE="$2"
        shift 2
        ;;
      --deliverables)
        DELIVERABLES="$2"
        shift 2
        ;;
      --design-changes)
        DESIGN_CHANGES="$2"
        shift 2
        ;;
      --test-command)
        TEST_COMMAND="$2"
        shift 2
        ;;
      --test-result)
        TEST_RESULT="$2"
        shift 2
        ;;
      --review-result)
        REVIEW_RESULT="$2"
        shift 2
        ;;
      --decision-basis)
        DECISION_BASIS="$2"
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
  [[ -n "$FEATURE_SLUG" ]] || die "missing required --feature"

  case "$RUNNER" in
    cx|cc|codex) ;;
    *) die "--runner must be cx, cc, or codex" ;;
  esac

  if [[ -n "$CONTENT" && -n "$CONTENT_FILE" ]]; then
    die "use only one of --content or --content-file"
  fi
}

ensure_runtime() {
  [[ -f "$PROJECT_ROOT/.claude/cx/状态.json" ]] || die "missing .claude/cx/状态.json"
  [[ -f "$PROJECT_ROOT/.claude/cx/core/projects/project.json" ]] || die "missing .claude/cx/core/projects/project.json"
  [[ -f "$PROJECT_ROOT/.claude/cx/core/features/$FEATURE_SLUG.json" ]] || die "missing feature record for $FEATURE_SLUG"
}

resolve_feature_title() {
  if [[ -n "$FEATURE_TITLE" ]]; then
    return
  fi

  FEATURE_TITLE=$(jq -r --arg slug "$FEATURE_SLUG" '.features[$slug].title // empty' "$PROJECT_ROOT/.claude/cx/状态.json" 2>/dev/null)
  if [[ -z "$FEATURE_TITLE" ]]; then
    FEATURE_TITLE=$(jq -r '.title // empty' "$PROJECT_ROOT/.claude/cx/core/features/$FEATURE_SLUG.json" 2>/dev/null)
  fi
  [[ -n "$FEATURE_TITLE" ]] || die "unable to resolve feature title for $FEATURE_SLUG"
}

feature_dir() {
  printf '%s/.claude/cx/功能/%s\n' "$PROJECT_ROOT" "$FEATURE_TITLE"
}

summary_file() {
  printf '%s/总结.md\n' "$(feature_dir)"
}

feature_status_file() {
  printf '%s/状态.json\n' "$(feature_dir)"
}

core_feature_file() {
  printf '%s/.claude/cx/core/features/%s.json\n' "$PROJECT_ROOT" "$FEATURE_SLUG"
}

worktree_file() {
  printf '%s/.claude/cx/core/worktrees/%s.json\n' "$PROJECT_ROOT" "$FEATURE_SLUG"
}

project_status_file() {
  printf '%s/.claude/cx/状态.json\n' "$PROJECT_ROOT"
}

core_project_file() {
  printf '%s/.claude/cx/core/projects/project.json\n' "$PROJECT_ROOT"
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

summary_commit_count() {
  jq -r '[.tasks[] | select(.commit != null and .commit != "") | .commit] | length' "$(feature_status_file)"
}

load_summary_content() {
  if [[ -n "$CONTENT_FILE" ]]; then
    [[ -f "$CONTENT_FILE" ]] || die "summary content file not found: $CONTENT_FILE"
    cat "$CONTENT_FILE"
    return
  fi

  if [[ -n "$CONTENT" ]]; then
    printf '%s\n' "$CONTENT"
    return
  fi

  {
    printf '# 总结文档：%s\n\n' "$FEATURE_TITLE"
    printf -- '- 保存路径：`.claude/cx/功能/%s/总结.md`\n' "$FEATURE_TITLE"
    printf -- '- 稳定 slug：`%s`\n\n' "$FEATURE_SLUG"

    printf '## 完成概览\n\n'
    printf -- '- 功能：%s\n' "$FEATURE_TITLE"
    printf -- '- 状态：`completed / summarized`\n'
    printf -- '- 总任务数：%s\n' "$(jq -r '.total' "$(feature_status_file)")"
    printf -- '- 相关提交：%s\n\n' "$(summary_commit_count)"

    printf '## 交付结果\n\n'
    pipe_to_bullets "$DELIVERABLES" "-" "待补充交付结果"
    printf '\n'

    printf '## 契约与设计变化\n\n'
    printf -- '- 是否调整设计：%s\n' "$(if [[ -n "$DESIGN_CHANGES" ]]; then printf '是'; else printf '否'; fi)"
    printf -- '- 调整内容：%s\n\n' "$(default_text "$DESIGN_CHANGES" "无")"

    printf '## 验证与审查\n\n'
    printf -- '- 测试命令：%s\n' "$(default_text "$TEST_COMMAND" "最相关验证已通过")"
    printf -- '- 结果：%s\n' "$TEST_RESULT"
    printf -- '- 审查结论：%s\n' "$REVIEW_RESULT"
  }
}

ensure_summarizable() {
  local feature_stage core_stage lease_session
  feature_stage=$(jq -r '.status' "$(feature_status_file)")
  core_stage=$(jq -r '.lifecycle.stage' "$(core_feature_file)")
  lease_session=$(jq -r --arg slug "$FEATURE_SLUG" '.features[$slug].lease_session_id // empty' "$(core_project_file)")

  if [[ "$FORCE" != "true" ]]; then
    [[ "$feature_stage" == "completed" ]] || die "feature status must be completed before summary"
    [[ "$core_stage" == "completed" ]] || die "core lifecycle must be completed before summary"
    if [[ -n "$lease_session" ]]; then
      [[ -n "$SESSION_ID" ]] || die "session id is required to release active lease for summary"
      [[ "$lease_session" == "$SESSION_ID" ]] || die "feature $FEATURE_SLUG is currently leased by $lease_session, not $SESSION_ID"
    fi
  fi
}

write_summary_doc() {
  mkdir -p "$(feature_dir)"
  load_summary_content > "$(summary_file)"
}

update_summary_state() {
  local now="$1"
  local decision_basis="$2"
  local feature_status core_feature project_status core_project
  local summary_doc_path

  summary_doc_path=".claude/cx/功能/$FEATURE_TITLE/总结.md"
  feature_status=$(cat "$(feature_status_file)")
  core_feature=$(cat "$(core_feature_file)")
  project_status=$(cat "$(project_status_file)")
  core_project=$(cat "$(core_project_file)")

  feature_status=$(jq \
    --arg now "$now" \
    --arg decision_basis "$decision_basis" \
    '
      .last_updated = $now
      | .status = "summarized"
      | .docs = ((.docs // {}) + {summary: "总结.md"})
      | .workflow.current_phase = "summary"
      | .workflow.completion_status = "done"
      | .workflow.next_route = null
      | .workflow.decision_basis = $decision_basis
      | .workflow.last_transition_at = $now
      | del(.blocked)
    ' <<< "$feature_status")

  core_feature=$(jq \
    --arg now "$now" \
    --arg decision_basis "$decision_basis" \
    --arg summary_doc_path "$summary_doc_path" \
    '
      .lifecycle.stage = "archived"
      | .lifecycle.updated_at = $now
      | .docs = ((.docs // {}) + {summary: $summary_doc_path})
      | .workflow.current_phase = "summary"
      | .workflow.completion_status = "done"
      | .workflow.next_route = null
      | .workflow.decision_basis = $decision_basis
      | .workflow.last_transition_at = $now
      | .worktree.binding_status = "released"
      | .lease.last_heartbeat = $now
      | .lease.claimed_tasks = []
    ' <<< "$core_feature")

  project_status=$(jq \
    --arg slug "$FEATURE_SLUG" \
    --arg now "$now" \
    '
      .last_updated = $now
      | if .current_feature == $slug then .current_feature = null else . end
      | .features[$slug].status = "summarized"
      | .features[$slug].last_updated = $now
    ' <<< "$project_status")

  core_project=$(jq \
    --arg slug "$FEATURE_SLUG" \
    --arg now "$now" \
    --arg session "$SESSION_ID" \
    '
      if .current_feature == $slug then .current_feature = null else . end
      | .features[$slug].lifecycle = "archived"
      | .features[$slug].lease_session_id = null
      | .features[$slug].workflow_phase = "summary"
      | .features[$slug].next_route = null
      | .features[$slug].last_updated = $now
      | if ($session != "" and (.active_sessions[$session] // null) != null) then
          .active_sessions[$session].last_heartbeat = $now
          | .active_sessions[$session].claimed_feature = null
          | .active_sessions[$session].claimed_tasks = []
        else
          .
        end
    ' <<< "$core_project")

  printf '%s\n' "$feature_status" > "$(feature_status_file)"
  printf '%s\n' "$core_feature" > "$(core_feature_file)"
  printf '%s\n' "$project_status" > "$(project_status_file)"
  printf '%s\n' "$core_project" > "$(core_project_file)"

  if [[ -f "$(worktree_file)" ]]; then
    jq --arg now "$now" '
      .binding_status = "released"
      | .updated_at = $now
    ' "$(worktree_file)" > "$(worktree_file).tmp"
    mv "$(worktree_file).tmp" "$(worktree_file)"
  fi
}

main() {
  parse_args "$@"
  detect_project_root
  validate_args
  ensure_runtime
  resolve_feature_title
  ensure_summarizable

  local now decision_basis
  now=$(now_iso)
  decision_basis=$(default_text "$DECISION_BASIS" "功能已完成闭环，进入归档状态。")

  write_summary_doc
  update_summary_state "$now" "$decision_basis"

  printf 'feature_slug=%s\n' "$FEATURE_SLUG"
  printf 'feature_title=%s\n' "$FEATURE_TITLE"
  printf 'next_route=\n'
}

main "$@"
