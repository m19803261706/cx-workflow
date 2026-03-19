#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

PROJECT_ROOT="${PROJECT_ROOT:-}"
FEATURE_SLUG=""
FEATURE_TITLE=""
RUNNER="cx"
SESSION_ID=""
CONTENT=""
CONTENT_FILE=""
NEEDS_ADR=""
QUESTION_MODE=""
DECISION_BASIS=""
FORCE="false"

usage() {
  cat <<'EOF'
usage: cx-workflow-design.sh --feature <slug> [OPTIONS]

Write a shared workflow design doc and advance the feature into the design phase.

OPTIONS:
  --project-root <path>         Project root
  --feature <slug>              Feature slug
  --title <text>                Optional Chinese title override
  --runner <cx|cc|codex>        Design runner (default: cx)
  --session-id <id>             Optional design session id
  --content <text>              Inline design content
  --content-file <path>         Design content file path
  --needs-adr <true|false>      Force next route to ADR or plan
  --question-mode <mode>        conversation | checklist | hybrid
  --decision-basis <text>       Why design is ready for the next route
  --force                       Allow design refresh on non-planning stages
  --help                        Show this help message
EOF
}

die() {
  echo "[cx-workflow-design] $*" >&2
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
      --needs-adr)
        NEEDS_ADR="$2"
        shift 2
        ;;
      --question-mode)
        QUESTION_MODE="$2"
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

  if [[ -n "$QUESTION_MODE" ]]; then
    case "$QUESTION_MODE" in
      conversation|checklist|hybrid) ;;
      *) die "--question-mode must be conversation, checklist, or hybrid" ;;
    esac
  fi

  if [[ -n "$NEEDS_ADR" ]]; then
    case "$NEEDS_ADR" in
      true|false) ;;
      *) die "--needs-adr must be true or false" ;;
    esac
  fi

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

design_file() {
  printf '%s/设计.md\n' "$(feature_dir)"
}

feature_status_file() {
  printf '%s/状态.json\n' "$(feature_dir)"
}

core_feature_file() {
  printf '%s/.claude/cx/core/features/%s.json\n' "$PROJECT_ROOT" "$FEATURE_SLUG"
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

load_design_content() {
  if [[ -n "$CONTENT_FILE" ]]; then
    [[ -f "$CONTENT_FILE" ]] || die "design content file not found: $CONTENT_FILE"
    cat "$CONTENT_FILE"
    return
  fi

  if [[ -n "$CONTENT" ]]; then
    printf '%s\n' "$CONTENT"
    return
  fi

  cat <<EOF
# 设计文档：$FEATURE_TITLE

- 保存路径：\`.claude/cx/功能/$FEATURE_TITLE/设计.md\`
- 稳定 slug：\`$FEATURE_SLUG\`
- 来源需求：\`需求.md\`

## 设计目标

围绕当前 PRD 锁定执行契约，保证后续任务拆分与实现路径清晰可验证。

## 架构边界

- 新增模块：待补充
- 修改模块：待补充
- 不在本次范围内：待补充

## API 接口契约

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 1 | POST | \`/api/...\` | 待补充 |

## 状态枚举对照表

| 场景 | 后端常量 | API 值 | 前端常量 | 显示文本 |
|------|---------|--------|---------|---------|
| 示例 | \`ENUM\` | \`VALUE\` | \`VALUE\` | 待补充 |

## VO / DTO 字段映射

| # | DB 字段 | DTO 字段 | API JSON | 前端字段 | 类型 | 必填 |
|---|---------|----------|----------|---------|------|------|
| 1 | db_field | dtoField | apiField | tsField | string | 是 |

## 风险点与测试重点

- 风险：待补充
- 测试重点：待补充
EOF
}

ensure_designable() {
  local stage
  stage=$(jq -r '.lifecycle.stage // "draft"' "$(core_feature_file)")

  if [[ "$FORCE" != "true" ]]; then
    case "$stage" in
      executing|blocked|completed|archived|handoff_pending)
        die "feature $FEATURE_SLUG is currently $stage; use --force to refresh design"
        ;;
    esac
  fi
}

resolve_next_route() {
  local existing
  if [[ -n "$NEEDS_ADR" ]]; then
    if [[ "$NEEDS_ADR" == "true" ]]; then
      printf 'cx-adr\n'
    else
      printf 'cx-plan\n'
    fi
    return
  fi

  existing=$(jq -r '.workflow.needs_adr // false' "$(core_feature_file)")
  if [[ "$existing" == "true" ]]; then
    printf 'cx-adr\n'
  else
    printf 'cx-plan\n'
  fi
}

resolve_question_mode() {
  if [[ -n "$QUESTION_MODE" ]]; then
    printf '%s\n' "$QUESTION_MODE"
  else
    jq -r '.workflow.question_mode // "conversation"' "$(core_feature_file)"
  fi
}

write_design_doc() {
  local design_doc="$1"
  mkdir -p "$(feature_dir)"
  load_design_content > "$design_doc"
}

update_status_files() {
  local now="$1"
  local next_route="$2"
  local question_mode="$3"
  local decision_basis="$4"
  local feature_status core_feature project_status core_project
  local design_doc_path

  design_doc_path=".claude/cx/功能/$FEATURE_TITLE/设计.md"
  feature_status=$(cat "$(feature_status_file)")
  core_feature=$(cat "$(core_feature_file)")
  project_status=$(cat "$(project_status_file)")
  core_project=$(cat "$(core_project_file)")

  feature_status=$(jq \
    --arg now "$now" \
    --arg next_route "$next_route" \
    --arg question_mode "$question_mode" \
    --arg decision_basis "$decision_basis" \
    '
      .last_updated = $now
      | .status = "planned"
      | .docs = ((.docs // {}) + {design: "设计.md"})
      | .workflow.current_phase = "design"
      | .workflow.completion_status = "ready"
      | .workflow.question_mode = $question_mode
      | .workflow.next_route = $next_route
      | .workflow.decision_basis = $decision_basis
      | .workflow.last_transition_at = $now
      | del(.blocked)
    ' <<< "$feature_status")

  core_feature=$(jq \
    --arg now "$now" \
    --arg next_route "$next_route" \
    --arg question_mode "$question_mode" \
    --arg decision_basis "$decision_basis" \
    --arg design_doc_path "$design_doc_path" \
    --arg runner "$RUNNER" \
    --arg session "$SESSION_ID" \
    '
      .title = .title
      | .lifecycle.stage = (if (.lifecycle.stage == "draft" or .lifecycle.stage == "ready") then "planned" else .lifecycle.stage end)
      | .lifecycle.updated_at = $now
      | if $session != "" then .planning_owner = {runner: $runner, session_id: $session} else . end
      | .docs = ((.docs // {}) + {design: $design_doc_path})
      | .workflow.current_phase = "design"
      | .workflow.completion_status = "ready"
      | .workflow.question_mode = $question_mode
      | .workflow.next_route = $next_route
      | .workflow.decision_basis = $decision_basis
      | .workflow.last_transition_at = $now
    ' <<< "$core_feature")

  project_status=$(jq \
    --arg slug "$FEATURE_SLUG" \
    --arg title "$FEATURE_TITLE" \
    --arg now "$now" \
    '
      .last_updated = $now
      | .current_feature = $slug
      | .features[$slug] = ((.features[$slug] // {}) + {
          title: $title,
          path: ("功能/" + $title),
          status: "planned",
          last_updated: $now
        })
    ' <<< "$project_status")

  core_project=$(jq \
    --arg slug "$FEATURE_SLUG" \
    --arg title "$FEATURE_TITLE" \
    --arg now "$now" \
    --arg next_route "$next_route" \
    --arg session "$SESSION_ID" \
    '
      .current_feature = $slug
      | .features[$slug].slug = $slug
      | .features[$slug].title = $title
      | .features[$slug].path = ".claude/cx/core/features/\($slug).json"
      | .features[$slug].lifecycle = "planned"
      | .features[$slug].workflow_phase = "design"
      | .features[$slug].next_route = $next_route
      | .features[$slug].last_updated = $now
      | if ($session != "" and (.active_sessions[$session] // null) != null) then
          .active_sessions[$session].last_heartbeat = $now
        else
          .
        end
    ' <<< "$core_project")

  printf '%s\n' "$feature_status" > "$(feature_status_file)"
  printf '%s\n' "$core_feature" > "$(core_feature_file)"
  printf '%s\n' "$project_status" > "$(project_status_file)"
  printf '%s\n' "$core_project" > "$(core_project_file)"
}

main() {
  parse_args "$@"
  detect_project_root
  validate_args
  ensure_runtime
  resolve_feature_title
  ensure_designable

  local now next_route question_mode decision_basis
  now=$(now_iso)
  next_route=$(resolve_next_route)
  question_mode=$(resolve_question_mode)
  decision_basis=$(default_text "$DECISION_BASIS" "设计契约已收敛，进入下一阶段。")

  write_design_doc "$(design_file)"
  update_status_files "$now" "$next_route" "$question_mode" "$decision_basis"

  printf 'feature_slug=%s\n' "$FEATURE_SLUG"
  printf 'feature_title=%s\n' "$FEATURE_TITLE"
  printf 'next_route=%s\n' "$next_route"
}

main "$@"
