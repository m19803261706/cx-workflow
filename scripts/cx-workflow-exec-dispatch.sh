#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-}"
FEATURE_SLUG=""
RUNNER=""
SESSION_ID=""
MODE="auto"
TASK_ID=""
OUTPUT_FORMAT="shell"

usage() {
  cat <<'EOF'
usage: cx-workflow-exec-dispatch.sh --feature <slug> --runner <cx|cc|codex> --session-id <id> [OPTIONS]

Shared exec dispatcher for cx workflow. It decides whether execution should continue,
ask about parallelization, stop for blocked/completed state, or escalate to --all mode.

OPTIONS:
  --project-root <path>    Project root
  --feature <slug>         Feature slug
  --runner <cx|cc|codex>   Runner identity
  --session-id <id>        Active session id
  --mode <auto|all>        Dispatch mode. all enables parallel-ready fanout
  --task <id>              Prefer a specific task
  --format <shell|json>    Output format
  --help                   Show this help message
EOF
}

die() {
  echo "[cx-workflow-exec-dispatch] $*" >&2
  exit 1
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
      --runner)
        RUNNER="$2"
        shift 2
        ;;
      --session-id)
        SESSION_ID="$2"
        shift 2
        ;;
      --mode)
        MODE="$2"
        shift 2
        ;;
      --task)
        TASK_ID="$2"
        shift 2
        ;;
      --format)
        OUTPUT_FORMAT="$2"
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
  [[ -n "$FEATURE_SLUG" ]] || die "missing required --feature"
  [[ -n "$RUNNER" ]] || die "missing required --runner"
  [[ -n "$SESSION_ID" ]] || die "missing required --session-id"

  case "$RUNNER" in
    cx|cc|codex) ;;
    *) die "--runner must be cx, cc, or codex" ;;
  esac

  case "$MODE" in
    auto|all) ;;
    *) die "--mode must be auto or all" ;;
  esac

  case "$OUTPUT_FORMAT" in
    shell|json) ;;
    *) die "--format must be shell or json" ;;
  esac
}

ensure_runtime() {
  [[ -f "$PROJECT_ROOT/.claude/cx/状态.json" ]] || die "missing .claude/cx/状态.json"
  [[ -f "$PROJECT_ROOT/.claude/cx/core/projects/project.json" ]] || die "missing .claude/cx/core/projects/project.json"
}

feature_title() {
  jq -r --arg slug "$FEATURE_SLUG" '.features[$slug].title // empty' "$PROJECT_ROOT/.claude/cx/状态.json"
}

feature_status_file() {
  local title
  title=$(feature_title)
  [[ -n "$title" ]] || die "feature $FEATURE_SLUG not found in 项目状态"
  printf '%s/.claude/cx/功能/%s/状态.json\n' "$PROJECT_ROOT" "$title"
}

core_feature_file() {
  printf '%s/.claude/cx/core/features/%s.json\n' "$PROJECT_ROOT" "$FEATURE_SLUG"
}

emit_output() {
  local payload="$1"

  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    printf '%s\n' "$payload"
    return
  fi

  jq -r '
    to_entries
    | map(
        if (.value | type) == "array" then
          "\(.key)=\(.value | map(tostring) | join(","))"
        elif .value == null then
          "\(.key)="
        elif (.value | type) == "boolean" then
          "\(.key)=\(.value)"
        else
          "\(.key)=\(.value)"
        end
      )
    | .[]
  ' <<<"$payload"
}

build_dispatch_payload() {
  jq -n \
    --arg slug "$FEATURE_SLUG" \
    --arg runner "$RUNNER" \
    --arg session "$SESSION_ID" \
    --arg mode "$MODE" \
    --arg task_id "$TASK_ID" \
    --slurpfile feature_status "$(feature_status_file)" \
    --slurpfile core_feature "$(core_feature_file)" '
    ($feature_status[0]) as $feature
    | ($core_feature[0]) as $core
    | ($feature.tasks // []) as $tasks
    | def task_by_number($task_no):
        first($tasks[] | select((.number | tostring) == ($task_no | tostring)));
      def ready_tasks:
        [$tasks[] | select(.status == "ready")];
      def in_progress_tasks:
        [$tasks[] | select(.status == "in_progress")];
      def parallel_candidates:
        (ready_tasks | map(select((.parallel_group // "") != "")) | group_by(.parallel_group) | map(select(length > 1)));
      def selected_task_numbers($entries):
        [$entries[] | .number];
      def blocked_message:
        ($feature.blocked.message // "当前功能已阻塞，等待用户决策。");
      if ($feature.status == "blocked") or (($core.workflow.completion_status // "") == "blocked") then
        {
          feature_slug: $slug,
          runner: $runner,
          session_id: $session,
          mode: $mode,
          decision: "blocked",
          prompt_required: true,
          prompt_kind: "blocked",
          selected_tasks: [],
          parallel_tasks: [],
          recommended_task: null,
          recommended_mode: null,
          message: blocked_message
        }
      elif (([$tasks[] | select(.status == "completed")] | length) == ($tasks | length) and ($tasks | length) > 0) then
        {
          feature_slug: $slug,
          runner: $runner,
          session_id: $session,
          mode: $mode,
          decision: "completed",
          prompt_required: false,
          prompt_kind: null,
          selected_tasks: [],
          parallel_tasks: [],
          recommended_task: null,
          recommended_mode: null,
          message: "全部任务已完成，下一步进入 cx-summary。"
        }
      elif ($task_id != "") then
        (task_by_number($task_id)) as $explicit
        | if $explicit == null then
            error("task_not_found")
          elif ($explicit.status == "blocked") then
            {
              feature_slug: $slug,
              runner: $runner,
              session_id: $session,
              mode: $mode,
              decision: "blocked",
              prompt_required: true,
              prompt_kind: "task_blocked",
              selected_tasks: [$explicit.number],
              parallel_tasks: [],
              recommended_task: $explicit.number,
              recommended_mode: null,
              message: "指定任务当前处于 blocked，需要先处理阻塞。"
            }
          elif ($explicit.status == "completed") then
            {
              feature_slug: $slug,
              runner: $runner,
              session_id: $session,
              mode: $mode,
              decision: "completed",
              prompt_required: false,
              prompt_kind: null,
              selected_tasks: [],
              parallel_tasks: [],
              recommended_task: null,
              recommended_mode: null,
              message: "指定任务已完成。"
            }
          elif ($explicit.status == "pending") then
            {
              feature_slug: $slug,
              runner: $runner,
              session_id: $session,
              mode: $mode,
              decision: "blocked",
              prompt_required: true,
              prompt_kind: "dependency_unmet",
              selected_tasks: [],
              parallel_tasks: [],
              recommended_task: null,
              recommended_mode: null,
              message: "指定任务依赖尚未满足，暂不能执行。"
            }
          else
            {
              feature_slug: $slug,
              runner: $runner,
              session_id: $session,
              mode: $mode,
              decision: "continue",
              prompt_required: false,
              prompt_kind: null,
              selected_tasks: [$explicit.number],
              parallel_tasks: [],
              recommended_task: $explicit.number,
              recommended_mode: null,
              message: "继续指定任务。"
            }
          end
      elif (in_progress_tasks | length) > 0 then
        {
          feature_slug: $slug,
          runner: $runner,
          session_id: $session,
          mode: $mode,
          decision: "continue",
          prompt_required: false,
          prompt_kind: null,
          selected_tasks: selected_task_numbers(in_progress_tasks),
          parallel_tasks: [],
          recommended_task: (in_progress_tasks[0].number // null),
          recommended_mode: null,
          message: "继续当前 in_progress 任务。"
        }
      elif (ready_tasks | length) == 0 then
        {
          feature_slug: $slug,
          runner: $runner,
          session_id: $session,
          mode: $mode,
          decision: "blocked",
          prompt_required: true,
          prompt_kind: "no_ready_tasks",
          selected_tasks: [],
          parallel_tasks: [],
          recommended_task: null,
          recommended_mode: null,
          message: "当前没有可执行的 ready 任务，请检查依赖、handoff 或阻塞状态。"
        }
      elif ($mode == "all" and (ready_tasks | length) > 1) then
        {
          feature_slug: $slug,
          runner: $runner,
          session_id: $session,
          mode: $mode,
          decision: "parallel",
          prompt_required: false,
          prompt_kind: null,
          selected_tasks: selected_task_numbers(ready_tasks),
          parallel_tasks: selected_task_numbers(ready_tasks),
          recommended_task: (ready_tasks[0].number // null),
          recommended_mode: "all",
          message: "进入 --all 团队模式，当前 ready 任务将并行推进。"
        }
      elif (parallel_candidates | length) > 0 then
        (parallel_candidates[0]) as $group
        | {
            feature_slug: $slug,
            runner: $runner,
            session_id: $session,
            mode: $mode,
            decision: "ask_parallel",
            prompt_required: true,
            prompt_kind: "parallel_ready",
            selected_tasks: [($group[0].number)],
            parallel_tasks: selected_task_numbers($group),
            recommended_task: ($group[0].number),
            recommended_mode: "sequential",
            message: ("检测到可并行任务组 " + ($group[0].parallel_group // "parallel") + "，默认可继续串行执行；如果想加速，可切到 --all 团队模式。")
          }
      else
        (ready_tasks[0]) as $next
        | {
            feature_slug: $slug,
            runner: $runner,
            session_id: $session,
            mode: $mode,
            decision: "continue",
            prompt_required: false,
            prompt_kind: null,
            selected_tasks: [$next.number],
            parallel_tasks: [],
            recommended_task: $next.number,
            recommended_mode: null,
            message: "继续下一个 ready 任务。"
          }
      end
    '
}

main() {
  parse_args "$@"
  detect_project_root
  validate_args
  ensure_runtime

  local payload
  payload=$(build_dispatch_payload)
  emit_output "$payload"
}

main "$@"
