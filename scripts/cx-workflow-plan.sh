#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

PROJECT_ROOT="${PROJECT_ROOT:-}"
FEATURE_SLUG=""
FEATURE_TITLE=""
RUNNER="cx"
SESSION_ID=""
PLAN_JSON=""
PLAN_JSON_FILE=""
PREFERRED_BRANCH=""
PREFERRED_WORKTREE_PATH=""
FORCE="false"

usage() {
  cat <<'EOF'
usage: cx-workflow-plan.sh --feature <slug> [OPTIONS]

Deterministically write task docs, feature status, shared task registry, and worktree recommendation.

OPTIONS:
  --project-root <path>           Project root
  --feature <slug>                Feature slug
  --title <text>                  Optional feature title override
  --runner <cx|cc|codex>          Planning runner (default: cx)
  --session-id <id>               Optional planning session id
  --plan-json <json>              Plan payload as inline JSON
  --plan-json-file <path>         Plan payload file path
  --preferred-branch <branch>     Preferred worktree branch (default: codex/<slug>)
  --preferred-worktree-path <p>   Preferred worktree path (default: /worktrees/<slug>)
  --force                         Allow replanning even if feature is executing
  --help                          Show this help message
EOF
}

die() {
  echo "[cx-workflow-plan] $*" >&2
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
      --plan-json)
        PLAN_JSON="$2"
        shift 2
        ;;
      --plan-json-file)
        PLAN_JSON_FILE="$2"
        shift 2
        ;;
      --preferred-branch)
        PREFERRED_BRANCH="$2"
        shift 2
        ;;
      --preferred-worktree-path)
        PREFERRED_WORKTREE_PATH="$2"
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

  if [[ -z "$PLAN_JSON" && -z "$PLAN_JSON_FILE" ]]; then
    die "one of --plan-json or --plan-json-file is required"
  fi

  if [[ -n "$PLAN_JSON" && -n "$PLAN_JSON_FILE" ]]; then
    die "use only one of --plan-json or --plan-json-file"
  fi
}

ensure_runtime() {
  [[ -f "$PROJECT_ROOT/.claude/cx/配置.json" ]] || die "missing .claude/cx/配置.json; run cx-init first"
  [[ -f "$PROJECT_ROOT/.claude/cx/状态.json" ]] || die "missing .claude/cx/状态.json; run cx-init first"
  [[ -f "$PROJECT_ROOT/.claude/cx/core/projects/project.json" ]] || die "missing shared core project registry; run PRD or migration first"
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

resolve_defaults() {
  if [[ -z "$PREFERRED_BRANCH" ]]; then
    PREFERRED_BRANCH="codex/$FEATURE_SLUG"
  fi

  if [[ -z "$PREFERRED_WORKTREE_PATH" ]]; then
    PREFERRED_WORKTREE_PATH="/worktrees/$FEATURE_SLUG"
  fi
}

load_plan_payload() {
  if [[ -n "$PLAN_JSON_FILE" ]]; then
    [[ -f "$PLAN_JSON_FILE" ]] || die "plan json file not found: $PLAN_JSON_FILE"
    cat "$PLAN_JSON_FILE"
  else
    printf '%s\n' "$PLAN_JSON"
  fi
}

validate_plan_payload() {
  local plan_payload="$1"

  jq -e '.tasks and (.tasks | type == "array") and (.tasks | length > 0)' <<< "$plan_payload" >/dev/null \
    || die "plan payload must contain a non-empty tasks array"
}

feature_dir() {
  printf '%s/.claude/cx/功能/%s\n' "$PROJECT_ROOT" "$FEATURE_TITLE"
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

task_dir() {
  printf '%s/任务\n' "$(feature_dir)"
}

task_file_path() {
  local number="$1"
  printf '%s/任务-%s.md\n' "$(task_dir)" "$number"
}

task_doc_path() {
  local number="$1"
  printf '.claude/cx/功能/%s/任务/任务-%s.md\n' "$FEATURE_TITLE" "$number"
}

ensure_feature_can_be_planned() {
  local lifecycle lease_session_id
  lifecycle=$(jq -r '.lifecycle.stage // "draft"' "$(core_feature_file)")
  lease_session_id=$(jq -r --arg slug "$FEATURE_SLUG" '.features[$slug].lease_session_id // empty' "$(core_project_file)")

  if [[ "$FORCE" != "true" ]]; then
    if [[ "$lifecycle" == "executing" || "$lifecycle" == "blocked" || "$lifecycle" == "handoff_pending" ]]; then
      die "feature $FEATURE_SLUG is currently $lifecycle; use --force to replan"
    fi
    if [[ -n "$lease_session_id" ]]; then
      die "feature $FEATURE_SLUG is leased by session $lease_session_id; use --force to replan"
    fi
  fi
}

default_phase_name() {
  local number="$1"
  printf '阶段%s\n' "$number"
}

ensure_task_dir() {
  mkdir -p "$(task_dir)"
}

array_to_csv() {
  local json="$1"
  jq -r 'if length == 0 then "无" else map(tostring) | join(", ") end' <<< "$json"
}

array_to_lines() {
  local json="$1"
  local prefix="$2"
  jq -r --arg prefix "$prefix" '
    if length == 0 then
      ($prefix + " 无")
    else
      map($prefix + " " + tostring) | join("\n")
    end
  ' <<< "$json"
}

ensure_plan_shape() {
  local plan_payload="$1"
  jq '
    .tasks = (
      .tasks
      | map(
          .number = (.number // .id)
          | .phase = (.phase // 1)
          | .parallel = (.parallel // false)
          | .depends_on = (.depends_on // [])
          | .goal = (.goal // "完成该任务的实现与验证。")
          | .modified_files = (.modified_files // [])
          | .created_files = (.created_files // [])
          | .test_files = (.test_files // [])
          | .acceptance = (.acceptance // [])
          | .api_contracts = (.api_contracts // [])
          | .enum_contracts = (.enum_contracts // [])
          | .field_mappings = (.field_mappings // [])
          | .parallel_group = (.parallel_group // null)
          | .related_apis = (.related_apis // [])
          | .related_enums = (.related_enums // [])
          | .related_fields = (.related_fields // [])
        )
    )
    | .phases = (
        if (.phases // []) | length > 0 then
          .phases
        else
          ([.tasks[] | .phase] | unique | sort | map({number: ., name: ("阶段" + (tostring))}))
        end
      )
  ' <<< "$plan_payload"
}

build_phases_json() {
  local plan_payload="$1"

  jq '
    . as $root
    | ($root.phases // [])
    | map(
        . as $phase
        | {
            number: ($phase.number // 1),
            name: ($phase.name // ("阶段" + (($phase.number // 1) | tostring))),
            status: "pending",
            tasks: (
              if (($phase.tasks // []) | length) > 0 then
                $phase.tasks
              else
                [$root.tasks[] | select(.phase == ($phase.number // 1)) | .number]
              end
            )
          }
        | if (($phase.depends_on // []) | length) > 0 then . + {depends_on: $phase.depends_on} else . end
        | if ($phase.parallel_group // null) != null then . + {parallel_group: $phase.parallel_group} else . end
      )
  ' <<< "$plan_payload"
}

build_status_tasks_json() {
  local plan_payload="$1"

  jq '
    .tasks
    | map({
        number: .number,
        title: .title,
        phase: .phase,
        parallel: .parallel,
        depends_on: .depends_on,
        parallel_group: .parallel_group,
        related_apis: .related_apis,
        related_enums: .related_enums,
        related_fields: .related_fields,
        status: (if (.depends_on | length) == 0 then "ready" else "pending" end)
      })
  ' <<< "$plan_payload"
}

build_core_tasks_json() {
  local plan_payload="$1"

  jq --arg feature_title "$FEATURE_TITLE" --arg feature_slug "$FEATURE_SLUG" '
    .tasks
    | map(
        . as $task
        | {
            id: $task.number,
            title: $task.title,
            phase: $task.phase,
            parallel: $task.parallel,
            depends_on: $task.depends_on,
            status: (if ($task.depends_on | length) == 0 then "ready" else "pending" end),
            owner_session_id: null,
            path: (".claude/cx/功能/" + $feature_title + "/任务/任务-" + ($task.number | tostring) + ".md")
          }
        | if ($task.parallel_group // null) != null then . + {parallel_group: $task.parallel_group} else . end
      )
  ' <<< "$plan_payload"
}

build_execution_order_json() {
  local plan_payload="$1"

  jq '
    if (.execution_order // []) | length > 0 then
      .execution_order
    else
      (.tasks | sort_by(.number) | map(.number))
    end
  ' <<< "$plan_payload"
}

write_task_docs() {
  local plan_payload="$1"
  local phase_name depends_on modified_files created_files test_files acceptance_1 acceptance_2 api_contracts enum_contracts field_mappings
  local number title goal task_json

  ensure_task_dir

  while IFS= read -r number; do
    task_json=$(jq -c --argjson number "$number" '.tasks[] | select(.number == $number)' <<< "$plan_payload")
    title=$(jq -r '.title' <<< "$task_json")
    phase_name=$(jq -r --argjson phase "$(jq -r '.phase' <<< "$task_json")" '
      first((.phases // [])[] | select(.number == $phase) | .name) // ("阶段" + ($phase | tostring))
    ' <<< "$plan_payload")
    depends_on=$(array_to_csv "$(jq '.depends_on' <<< "$task_json")")
    modified_files=$(array_to_csv "$(jq '.modified_files' <<< "$task_json")")
    created_files=$(array_to_csv "$(jq '.created_files' <<< "$task_json")")
    test_files=$(array_to_csv "$(jq '.test_files' <<< "$task_json")")
    acceptance_1=$(jq -r '.acceptance[0] // "完成该任务的主实现。"' <<< "$task_json")
    acceptance_2=$(jq -r '.acceptance[1] // "完成与该任务直接相关的验证。"' <<< "$task_json")
    api_contracts=$(array_to_lines "$(jq '.api_contracts' <<< "$task_json")" "-")
    enum_contracts=$(array_to_lines "$(jq '.enum_contracts' <<< "$task_json")" "-")
    field_mappings=$(array_to_lines "$(jq '.field_mappings' <<< "$task_json")" "-")
    goal=$(jq -r '.goal' <<< "$task_json")

    cat > "$(task_file_path "$number")" <<EOF
# 任务 ${number}：${title}

- 保存路径：\`.claude/cx/功能/${FEATURE_TITLE}/任务/任务-${number}.md\`

## 元信息

- 功能标题：${FEATURE_TITLE}
- 稳定 slug：${FEATURE_SLUG}
- 阶段：${phase_name}
- 依赖：${depends_on}

## 任务目标

${goal}

## 目标文件

- 修改：\`${modified_files}\`
- 新增：\`${created_files}\`
- 测试：\`${test_files}\`

## 验收标准

- [ ] ${acceptance_1}
- [ ] ${acceptance_2}
- [ ] 契约与状态字段保持一致
- [ ] 提交信息使用 \`[cx:${FEATURE_SLUG}] [task:${number}]\`

## 契约片段

### 关联接口

${api_contracts}

### 关联枚举

${enum_contracts}

### 字段映射

${field_mappings}

## 阻塞处理

如任务进入 \`blocked\`，请在 feature 级 \`状态.json\` 中记录：

\`\`\`json
{
  "reason_type": "needs_decision",
  "message": "需要确认 API 契约调整"
}
\`\`\`
EOF
  done < <(jq -r '.tasks[] | .number' <<< "$plan_payload")
}

write_feature_status() {
  local plan_payload="$1"
  local now="$2"
  local created_at docs_json phases_json tasks_json execution_order_json existing_json

  created_at=$(jq -r '.created_at // empty' "$(feature_status_file)" 2>/dev/null)
  if [[ -z "$created_at" ]]; then
    created_at="$now"
  fi

  docs_json=$(jq '
    {
      prd: (.docs.prd // "需求.md"),
      design: (.docs.design // "设计.md"),
      summary: (.docs.summary // "总结.md")
    }
  ' "$(feature_status_file)" 2>/dev/null || printf '{"prd":"需求.md","design":"设计.md","summary":"总结.md"}')

  phases_json=$(build_phases_json "$plan_payload")
  tasks_json=$(build_status_tasks_json "$plan_payload")
  execution_order_json=$(build_execution_order_json "$plan_payload")
  existing_json=$(cat "$(feature_status_file)" 2>/dev/null || printf '{}')

  jq -n \
    --arg feature "$FEATURE_TITLE" \
    --arg slug "$FEATURE_SLUG" \
    --arg created_at "$created_at" \
    --arg now "$now" \
    --argjson existing "$existing_json" \
    --argjson docs "$docs_json" \
    --argjson phases "$phases_json" \
    --argjson tasks "$tasks_json" \
    --argjson execution_order "$execution_order_json" \
    '{
      feature: $feature,
      slug: $slug,
      created_at: $created_at,
      last_updated: $now,
      status: "planned",
      total: ($tasks | length),
      completed: 0,
      in_progress: 0,
      phases: $phases,
      tasks: $tasks,
      execution_order: $execution_order,
      docs: $docs,
      workflow: {
        protocol_version: "1.0",
        current_phase: "plan",
        completion_status: "ready",
        question_mode: ($existing.workflow.question_mode // "conversation"),
        size: ($existing.workflow.size // null),
        needs_design: ($existing.workflow.needs_design // null),
        needs_adr: ($existing.workflow.needs_adr // null),
        next_route: "cx-exec",
        decision_basis: "任务拆分已完成，等待进入执行阶段。",
        last_transition_at: $now
      }
    }' > "$(feature_status_file).tmp"
  mv "$(feature_status_file).tmp" "$(feature_status_file)"
}

write_core_feature() {
  local plan_payload="$1"
  local now="$2"
  local core_tasks_json planning_owner_json docs_json existing_workflow_json

  core_tasks_json=$(build_core_tasks_json "$plan_payload")
  existing_workflow_json=$(jq -c '.workflow // {}' "$(core_feature_file)")

  if [[ -n "$SESSION_ID" ]]; then
    planning_owner_json=$(jq -cn --arg runner "$RUNNER" --arg session "$SESSION_ID" '{runner: $runner, session_id: $session}')
  else
    planning_owner_json="null"
  fi

  docs_json=$(jq '.docs' "$(core_feature_file)")

  jq \
    --arg title "$FEATURE_TITLE" \
    --arg now "$now" \
    --arg branch "$PREFERRED_BRANCH" \
    --arg worktree "$PREFERRED_WORKTREE_PATH" \
    --argjson existing_workflow "$existing_workflow_json" \
    --argjson planning_owner "$planning_owner_json" \
    --argjson tasks "$core_tasks_json" \
    --argjson docs "$docs_json" '
      .title = $title
      | .lifecycle.stage = "ready"
      | .lifecycle.updated_at = $now
      | .planning_owner = $planning_owner
      | .worktree.branch = $branch
      | .worktree.worktree_path = $worktree
      | .worktree.binding_status = "unbound"
      | .tasks = $tasks
      | .workflow = (
          $existing_workflow
          + {
              protocol_version: "1.0",
              current_phase: "plan",
              completion_status: "ready",
              question_mode: ($existing_workflow.question_mode // "conversation"),
              size: ($existing_workflow.size // null),
              needs_design: ($existing_workflow.needs_design // null),
              needs_adr: ($existing_workflow.needs_adr // null),
              next_route: "cx-exec",
              decision_basis: "任务拆分已完成，等待进入执行阶段。",
              last_transition_at: $now
            }
        )
      | .docs = $docs
    ' "$(core_feature_file)" > "$(core_feature_file).tmp"
  mv "$(core_feature_file).tmp" "$(core_feature_file)"
}

update_project_status() {
  local now="$1"

  # DEPRECATED: current_feature is a hint for non-worktree fallback.
  # Primary feature context comes from worktree branch name.
  jq \
    --arg slug "$FEATURE_SLUG" \
    --arg title "$FEATURE_TITLE" \
    --arg path "功能/$FEATURE_TITLE" \
    --arg now "$now" '
      .last_updated = $now
      | .current_feature = $slug
      | .features[$slug] = (
          (.features[$slug] // {})
          + {
              title: $title,
              path: $path,
              status: "planned",
              last_updated: $now
            }
        )
    ' "$(project_status_file)" > "$(project_status_file).tmp"
  mv "$(project_status_file).tmp" "$(project_status_file)"
}

update_core_project_registry() {
  local now="$1"

  # DEPRECATED: current_feature is a hint for non-worktree fallback.
  # Primary feature context comes from worktree branch name.
  jq \
    --arg slug "$FEATURE_SLUG" \
    --arg title "$FEATURE_TITLE" \
    --arg path ".claude/cx/core/features/$FEATURE_SLUG.json" \
    --arg worktree "$PREFERRED_WORKTREE_PATH" \
    --arg now "$now" '
      .current_feature = $slug
      | .features[$slug].slug = $slug
      | .features[$slug].title = $title
      | .features[$slug].path = $path
      | .features[$slug].lifecycle = "ready"
      | .features[$slug].worktree_path = $worktree
      | .features[$slug].lease_session_id = null
      | .features[$slug].workflow_phase = "plan"
      | .features[$slug].next_route = "cx-exec"
      | .features[$slug].last_updated = $now
    ' "$(core_project_file)" > "$(core_project_file).tmp"
  mv "$(core_project_file).tmp" "$(core_project_file)"
}

recommend_worktree() {
  PROJECT_ROOT="$PROJECT_ROOT" bash "$SCRIPT_DIR/cx-core-worktree.sh" \
    --project-root "$PROJECT_ROOT" \
    --feature "$FEATURE_SLUG" \
    --branch "$PREFERRED_BRANCH" \
    --worktree-path "$PREFERRED_WORKTREE_PATH" >/dev/null
}

main() {
  parse_args "$@"
  detect_project_root
  validate_args
  ensure_runtime
  resolve_feature_title
  resolve_defaults
  ensure_feature_can_be_planned

  local now plan_payload
  now=$(now_iso)
  plan_payload=$(load_plan_payload)
  validate_plan_payload "$plan_payload"
  plan_payload=$(ensure_plan_shape "$plan_payload")

  write_task_docs "$plan_payload"
  write_feature_status "$plan_payload" "$now"
  write_core_feature "$plan_payload" "$now"
  recommend_worktree
  update_project_status "$now"
  update_core_project_registry "$now"

  printf 'feature_slug=%s\n' "$FEATURE_SLUG"
  printf 'feature_title=%s\n' "$FEATURE_TITLE"
  printf 'next_route=cx-exec\n'
  printf 'preferred_branch=%s\n' "$PREFERRED_BRANCH"
  printf 'preferred_worktree_path=%s\n' "$PREFERRED_WORKTREE_PATH"
}

main "$@"
