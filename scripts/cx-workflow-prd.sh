#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

PROJECT_ROOT="${PROJECT_ROOT:-}"
FEATURE_TITLE=""
FEATURE_SLUG=""
RUNNER="cx"
SESSION_ID=""
SIZE="M"
NEEDS_DESIGN=""
QUESTION_MODE="conversation"
BACKGROUND=""
SCENARIOS=""
REQUIREMENTS=""
ACCEPTANCE=""
FRONTEND_IMPACT=""
BACKEND_IMPACT=""
DATA_IMPACT=""
OTHER_IMPACT=""
RISKS=""
OPEN_QUESTIONS=""
DECISION_BASIS=""

usage() {
  cat <<'EOF'
usage: cx-workflow-prd.sh --title <中文标题> [OPTIONS]

Deterministically scaffold and register a feature PRD in the shared cx workflow core.

OPTIONS:
  --project-root <path>         Project root (defaults to git top-level or current directory)
  --title <text>                Chinese feature title
  --slug <slug>                 Stable slug; auto-derived if omitted
  --runner <cx|cc|codex>        Runner identity for planning metadata
  --session-id <id>             Optional planning session id
  --size <S|M|L>                Suggested feature size (default: M)
  --needs-design <true|false>   Force the design decision
  --question-mode <mode>        conversation | checklist | hybrid
  --background <text>           Background and goal summary
  --scenarios <a|b|c>           Pipe-separated user scenarios
  --requirements <a|b|c>        Pipe-separated requirements
  --acceptance <a|b|c>          Pipe-separated acceptance criteria
  --front-end <text>            Frontend impact summary
  --back-end <text>             Backend impact summary
  --data-layer <text>           Data layer impact summary
  --other-deps <text>           Other dependencies summary
  --risks <a|b|c>               Pipe-separated risks
  --open-questions <a|b|c>      Pipe-separated open questions
  --decision-basis <text>       Why this size/design route was chosen
  --help                        Show this help message
EOF
}

die() {
  echo "[cx-workflow-prd] $*" >&2
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
        FEATURE_TITLE="$2"
        shift 2
        ;;
      --slug)
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
      --size)
        SIZE="$2"
        shift 2
        ;;
      --needs-design)
        NEEDS_DESIGN="$2"
        shift 2
        ;;
      --question-mode)
        QUESTION_MODE="$2"
        shift 2
        ;;
      --background)
        BACKGROUND="$2"
        shift 2
        ;;
      --scenarios)
        SCENARIOS="$2"
        shift 2
        ;;
      --requirements)
        REQUIREMENTS="$2"
        shift 2
        ;;
      --acceptance)
        ACCEPTANCE="$2"
        shift 2
        ;;
      --front-end)
        FRONTEND_IMPACT="$2"
        shift 2
        ;;
      --back-end)
        BACKEND_IMPACT="$2"
        shift 2
        ;;
      --data-layer)
        DATA_IMPACT="$2"
        shift 2
        ;;
      --other-deps)
        OTHER_IMPACT="$2"
        shift 2
        ;;
      --risks)
        RISKS="$2"
        shift 2
        ;;
      --open-questions)
        OPEN_QUESTIONS="$2"
        shift 2
        ;;
      --decision-basis)
        DECISION_BASIS="$2"
        shift 2
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
  [[ -n "$FEATURE_TITLE" ]] || die "missing required --title"

  case "$RUNNER" in
    cx|cc|codex) ;;
    *) die "--runner must be cx, cc, or codex" ;;
  esac

  case "$SIZE" in
    S|M|L) ;;
    *) die "--size must be S, M, or L" ;;
  esac

  case "$QUESTION_MODE" in
    conversation|checklist|hybrid) ;;
    *) die "--question-mode must be conversation, checklist, or hybrid" ;;
  esac

  if [[ -n "$NEEDS_DESIGN" ]]; then
    case "$NEEDS_DESIGN" in
      true|false) ;;
      *) die "--needs-design must be true or false" ;;
    esac
  fi
}

slugify() {
  local title="$1"
  local normalized

  normalized=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
  if [[ -z "$normalized" ]]; then
    normalized="feature-$(printf '%s' "$title" | shasum | awk '{print $1}' | cut -c1-10)"
  fi
  printf '%s\n' "$normalized"
}

resolve_feature_slug() {
  if [[ -z "$FEATURE_SLUG" ]]; then
    FEATURE_SLUG=$(slugify "$FEATURE_TITLE")
  fi
}

resolve_needs_design() {
  if [[ -n "$NEEDS_DESIGN" ]]; then
    return
  fi

  if [[ "$SIZE" == "S" ]]; then
    NEEDS_DESIGN="false"
  else
    NEEDS_DESIGN="true"
  fi
}

ensure_initialized() {
  [[ -f "$PROJECT_ROOT/.claude/cx/配置.json" ]] || die "missing .claude/cx/配置.json; run cx-init first"
  [[ -f "$PROJECT_ROOT/.claude/cx/状态.json" ]] || die "missing .claude/cx/状态.json; run cx-init first"
}

ensure_core() {
  if [[ -f "$PROJECT_ROOT/.claude/cx/core/projects/project.json" ]]; then
    return
  fi

  PROJECT_ROOT="$PROJECT_ROOT" bash "$SCRIPT_DIR/cx-core-migrate.sh" --project-root "$PROJECT_ROOT"
}

ensure_dirs() {
  mkdir -p "$PROJECT_ROOT/.claude/cx/功能/$FEATURE_TITLE/任务"
  mkdir -p "$PROJECT_ROOT/.claude/cx/runtime/$RUNNER"
  mkdir -p "$PROJECT_ROOT/.claude/cx/core/features"
  mkdir -p "$PROJECT_ROOT/.claude/cx/core/worktrees"
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

pipe_to_numbered() {
  local raw="$1"
  local fallback="$2"
  local index=1
  local item=""

  if [[ -z "$raw" ]]; then
    printf '1. %s\n' "$fallback"
    return
  fi

  IFS='|' read -r -a items <<< "$raw"
  for item in "${items[@]}"; do
    printf '%s. %s\n' "$index" "$item"
    index=$((index + 1))
  done
}

write_prd_doc() {
  local prd_file="$1"
  local size_decision next_route needs_design_label

  if [[ "$NEEDS_DESIGN" == "true" ]]; then
    needs_design_label="是"
    next_route="cx-design"
  else
    needs_design_label="否"
    next_route="cx-plan"
  fi

  size_decision=$(default_text "$DECISION_BASIS" "根据影响范围、跨端范围和风险评估得到当前规模建议。")

  {
    printf '# 需求文档：%s\n\n' "$FEATURE_TITLE"
    printf -- '- 保存路径：`.claude/cx/功能/%s/需求.md`\n' "$FEATURE_TITLE"
    printf -- '- 稳定 slug：`%s`\n' "$FEATURE_SLUG"
    printf -- '- 当前状态：`drafting`\n'
    printf -- '- 共享 workflow 协议：`1.0`\n'
    printf -- '- 下一步建议：`%s`\n\n' "$next_route"

    printf '## 背景与目标\n\n'
    printf '%s\n\n' "$(default_text "$BACKGROUND" "待与用户补充更细背景；当前先以最小可执行 PRD 立项。")"

    printf '## 用户场景\n\n'
    pipe_to_bullets "$SCENARIOS" "-" "待补充核心用户场景"
    printf '\n'

    printf '## 功能需求\n\n'
    pipe_to_numbered "$REQUIREMENTS" "待补充功能需求"
    printf '\n'

    printf '## 影响范围\n\n'
    printf -- '- 前端：%s\n' "$(default_text "$FRONTEND_IMPACT" "待补充")"
    printf -- '- 后端：%s\n' "$(default_text "$BACKEND_IMPACT" "待补充")"
    printf -- '- 数据层：%s\n' "$(default_text "$DATA_IMPACT" "待补充")"
    printf -- '- 其他依赖：%s\n\n' "$(default_text "$OTHER_IMPACT" "待补充")"

    printf '## 验收标准\n\n'
    pipe_to_bullets "$ACCEPTANCE" "- [ ]" "待补充验收标准"
    printf '\n'

    printf '## 风险与未决问题\n\n'
    printf '### 风险\n\n'
    pipe_to_bullets "$RISKS" "-" "待补充风险"
    printf '\n### 未决问题\n\n'
    pipe_to_bullets "$OPEN_QUESTIONS" "-" "待补充未决问题"
    printf '\n'

    printf '## 规模评估\n\n'
    printf -- '- 建议规模：`%s`\n' "$SIZE"
    printf -- '- 是否需要 Design：[%s]\n' "$needs_design_label"
    printf -- '- 问答模式：`%s`\n' "$QUESTION_MODE"
    printf -- '- 判断依据：%s\n' "$size_decision"
  } > "$prd_file"
}

write_feature_status() {
  local status_file="$1"
  local now="$2"
  local next_route needs_adr

  if [[ "$NEEDS_DESIGN" == "true" ]]; then
    next_route="cx-design"
  else
    next_route="cx-plan"
  fi

  if [[ "$SIZE" == "L" ]]; then
    needs_adr="true"
  else
    needs_adr="false"
  fi

  jq -n \
    --arg feature "$FEATURE_TITLE" \
    --arg slug "$FEATURE_SLUG" \
    --arg now "$now" \
    --arg size "$SIZE" \
    --arg next_route "$next_route" \
    --arg question_mode "$QUESTION_MODE" \
    --arg decision_basis "$(default_text "$DECISION_BASIS" "PRD 已完成最小收敛，等待进入下一阶段。")" \
    --arg prd "需求.md" \
    --argjson needs_design "$NEEDS_DESIGN" \
    --argjson needs_adr "$needs_adr" \
    '{
      feature: $feature,
      slug: $slug,
      created_at: $now,
      last_updated: $now,
      status: "drafting",
      total: 0,
      completed: 0,
      in_progress: 0,
      phases: [],
      tasks: [],
      execution_order: [],
      docs: {
        prd: $prd
      },
      workflow: {
        protocol_version: "1.0",
        current_phase: "prd",
        completion_status: "ready",
        question_mode: $question_mode,
        size: $size,
        needs_design: $needs_design,
        needs_adr: $needs_adr,
        next_route: $next_route,
        decision_basis: $decision_basis,
        last_transition_at: $now
      }
    }' > "$status_file"
}

write_feature_record() {
  local feature_file="$1"
  local now="$2"
  local feature_doc_path="$3"
  local next_route needs_adr planning_owner_json workflow_json

  if [[ "$NEEDS_DESIGN" == "true" ]]; then
    next_route="cx-design"
  else
    next_route="cx-plan"
  fi

  if [[ "$SIZE" == "L" ]]; then
    needs_adr="true"
  else
    needs_adr="false"
  fi

  if [[ -n "$SESSION_ID" ]]; then
    planning_owner_json=$(jq -cn --arg runner "$RUNNER" --arg session_id "$SESSION_ID" '{runner: $runner, session_id: $session_id}')
  else
    planning_owner_json="null"
  fi

  workflow_json=$(jq -cn \
    --arg size "$SIZE" \
    --arg next_route "$next_route" \
    --arg question_mode "$QUESTION_MODE" \
    --arg decision_basis "$(default_text "$DECISION_BASIS" "PRD 已完成最小收敛，等待进入下一阶段。")" \
    --arg now "$now" \
    --argjson needs_design "$NEEDS_DESIGN" \
    --argjson needs_adr "$needs_adr" \
    '{
      protocol_version: "1.0",
      current_phase: "prd",
      completion_status: "ready",
      question_mode: $question_mode,
      size: $size,
      needs_design: $needs_design,
      needs_adr: $needs_adr,
      next_route: $next_route,
      decision_basis: $decision_basis,
      last_transition_at: $now
    }')

  if [[ -f "$feature_file" ]]; then
    jq \
      --arg title "$FEATURE_TITLE" \
      --arg now "$now" \
      --arg feature_doc_path "$feature_doc_path" \
      --argjson workflow "$workflow_json" \
      --argjson planning_owner "$planning_owner_json" \
      '
        .title = $title
        | .lifecycle.stage = "draft"
        | .lifecycle.updated_at = $now
        | .planning_owner = $planning_owner
        | .docs.prd = $feature_doc_path
        | .workflow = $workflow
      ' "$feature_file" > "$feature_file.tmp"
    mv "$feature_file.tmp" "$feature_file"
    return
  fi

  jq -n \
    --arg slug "$FEATURE_SLUG" \
    --arg title "$FEATURE_TITLE" \
    --arg now "$now" \
    --arg feature_doc_path "$feature_doc_path" \
    --arg branch "feature/$FEATURE_SLUG" \
    --arg worktree_path "/worktrees/$FEATURE_SLUG" \
    --arg lease_session "cx-placeholder-$FEATURE_SLUG" \
    --argjson planning_owner "$planning_owner_json" \
    --argjson workflow "$workflow_json" \
    '{
      slug: $slug,
      title: $title,
      lifecycle: {
        stage: "draft",
        updated_at: $now
      },
      planning_owner: $planning_owner,
      execution_owner: null,
      worktree: {
        branch: $branch,
        worktree_path: $worktree_path,
        binding_status: "unbound"
      },
      lease: {
        runner: "cx",
        session_id: $lease_session,
        branch: $branch,
        worktree_path: $worktree_path,
        claimed_feature: $slug,
        claimed_tasks: [],
        claimed_at: $now,
        last_heartbeat: $now,
        expires_at: $now
      },
      docs: {
        prd: $feature_doc_path
      },
      workflow: $workflow,
      tasks: [],
      handoffs: []
    }' > "$feature_file"
}

write_worktree_recommendation() {
  local worktree_file="$1"
  local now="$2"

  jq -n \
    --arg slug "$FEATURE_SLUG" \
    --arg now "$now" \
    --arg preferred_worktree_path "/worktrees/$FEATURE_SLUG" \
    --arg preferred_branch "codex/$FEATURE_SLUG" \
    --arg record_path ".claude/cx/core/worktrees/$FEATURE_SLUG.json" \
    '{
      feature_slug: $slug,
      preferred_worktree_path: $preferred_worktree_path,
      preferred_branch: $preferred_branch,
      binding_status: "recommended",
      updated_at: $now,
      bound_at: null,
      runner: null,
      session_id: null,
      current_worktree_path: null,
      current_branch: null,
      record_path: $record_path
    }' > "$worktree_file"
}

update_project_status() {
  local status_file="$1"
  local now="$2"

  jq \
    --arg slug "$FEATURE_SLUG" \
    --arg title "$FEATURE_TITLE" \
    --arg path "功能/$FEATURE_TITLE" \
    --arg now "$now" \
    '
      .last_updated = $now
      | .current_feature = $slug
      | .features[$slug] = {
          title: $title,
          path: $path,
          status: "drafting"
        }
    ' "$status_file" > "$status_file.tmp"
  mv "$status_file.tmp" "$status_file"
}

update_core_project_registry() {
  local registry_file="$1"
  local now="$2"
  local next_route

  if [[ "$NEEDS_DESIGN" == "true" ]]; then
    next_route="cx-design"
  else
    next_route="cx-plan"
  fi

  jq \
    --arg slug "$FEATURE_SLUG" \
    --arg title "$FEATURE_TITLE" \
    --arg path ".claude/cx/core/features/$FEATURE_SLUG.json" \
    --arg worktree_path "/worktrees/$FEATURE_SLUG" \
    --arg workflow_phase "prd" \
    --arg next_route "$next_route" \
    --arg now "$now" \
    '
      .current_feature = $slug
      | .features[$slug] = {
          slug: $slug,
          title: $title,
          path: $path,
          lifecycle: "draft",
          worktree_path: $worktree_path,
          lease_session_id: null,
          workflow_phase: $workflow_phase,
          next_route: $next_route,
          last_updated: $now
        }
    ' "$registry_file" > "$registry_file.tmp"
  mv "$registry_file.tmp" "$registry_file"
}

main() {
  parse_args "$@"
  detect_project_root
  validate_args
  resolve_feature_slug
  resolve_needs_design
  ensure_initialized
  ensure_core
  ensure_dirs

  local now cx_dir feature_dir prd_file feature_status_file core_feature_file core_project_file worktree_file
  local feature_doc_path

  now=$(now_iso)
  cx_dir="$PROJECT_ROOT/.claude/cx"
  feature_dir="$cx_dir/功能/$FEATURE_TITLE"
  prd_file="$feature_dir/需求.md"
  feature_status_file="$feature_dir/状态.json"
  core_feature_file="$cx_dir/core/features/$FEATURE_SLUG.json"
  core_project_file="$cx_dir/core/projects/project.json"
  worktree_file="$cx_dir/core/worktrees/$FEATURE_SLUG.json"
  feature_doc_path=".claude/cx/功能/$FEATURE_TITLE/需求.md"

  write_prd_doc "$prd_file"
  write_feature_status "$feature_status_file" "$now"
  write_feature_record "$core_feature_file" "$now" "$feature_doc_path"
  write_worktree_recommendation "$worktree_file" "$now"
  update_project_status "$cx_dir/状态.json" "$now"
  update_core_project_registry "$core_project_file" "$now"

  printf 'feature_title=%s\n' "$FEATURE_TITLE"
  printf 'feature_slug=%s\n' "$FEATURE_SLUG"
  printf 'next_route=%s\n' "$(if [[ "$NEEDS_DESIGN" == "true" ]]; then echo cx-design; else echo cx-plan; fi)"
  printf 'project_root=%s\n' "$PROJECT_ROOT"
}

main "$@"
