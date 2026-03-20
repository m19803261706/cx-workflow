#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/cx-lib.sh"

PROJECT_ROOT="${PROJECT_ROOT:-}"
FEATURE_SLUG=""
RUNNER=""
SESSION_ID=""
BRANCH=""
WORKTREE_PATH=""
CURRENT_BRANCH=""
CURRENT_WORKTREE_PATH=""
ACTION=""
TASK_ID=""
COMMIT_SHA=""
REASON_TYPE=""
MESSAGE=""

usage() {
  cat <<'EOF'
usage: cx-workflow-exec.sh --feature <slug> --runner <cx|cc|codex> --session-id <id> --branch <branch> --worktree-path <path> --action <start|complete|block> --task <id> [OPTIONS]

Drive shared workflow exec state transitions after lease/worktree validation.

OPTIONS:
  --project-root <path>          Project root
  --feature <slug>               Feature slug
  --runner <cx|cc|codex>         Execution runner
  --session-id <id>              Active session id
  --branch <branch>              Execution branch
  --worktree-path <path>         Execution worktree path
  --current-branch <branch>      Current checkout branch override
  --current-worktree-path <p>    Current checkout worktree override
  --action <start|complete|block>
  --task <id>                    Task number or id
  --commit <sha>                 Commit sha for complete action
  --reason-type <type>           Block reason type
  --message <text>               Block reason message
  --help                         Show this help message
EOF
}

die() {
  echo "[cx-workflow-exec] $*" >&2
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
      --runner)
        RUNNER="$2"
        shift 2
        ;;
      --session-id)
        SESSION_ID="$2"
        shift 2
        ;;
      --branch)
        BRANCH="$2"
        shift 2
        ;;
      --worktree-path)
        WORKTREE_PATH="$2"
        shift 2
        ;;
      --current-branch)
        CURRENT_BRANCH="$2"
        shift 2
        ;;
      --current-worktree-path)
        CURRENT_WORKTREE_PATH="$2"
        shift 2
        ;;
      --action)
        ACTION="$2"
        shift 2
        ;;
      --task)
        TASK_ID="$2"
        shift 2
        ;;
      --commit)
        COMMIT_SHA="$2"
        shift 2
        ;;
      --reason-type)
        REASON_TYPE="$2"
        shift 2
        ;;
      --message)
        MESSAGE="$2"
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
  [[ -n "$BRANCH" ]] || die "missing required --branch"
  [[ -n "$WORKTREE_PATH" ]] || die "missing required --worktree-path"
  [[ -n "$ACTION" ]] || die "missing required --action"
  [[ -n "$TASK_ID" ]] || die "missing required --task"

  case "$RUNNER" in
    cx|cc|codex) ;;
    *) die "--runner must be cx, cc, or codex" ;;
  esac

  case "$ACTION" in
    start|complete|block) ;;
    *) die "--action must be start, complete, or block" ;;
  esac

  if [[ "$ACTION" == "block" ]]; then
    [[ -n "$REASON_TYPE" ]] || die "--reason-type is required for block"
    [[ -n "$MESSAGE" ]] || die "--message is required for block"
  fi
}

ensure_runtime() {
  [[ -f "$PROJECT_ROOT/.claude/cx/状态.json" ]] || die "missing .claude/cx/状态.json"
  [[ -f "$PROJECT_ROOT/.claude/cx/core/projects/project.json" ]] || die "missing .claude/cx/core/projects/project.json"
  [[ -f "$PROJECT_ROOT/.claude/cx/core/features/$FEATURE_SLUG.json" ]] || die "missing feature record for $FEATURE_SLUG"
}

feature_title() {
  jq -r --arg slug "$FEATURE_SLUG" '.features[$slug].title // empty' "$PROJECT_ROOT/.claude/cx/状态.json"
}

feature_status_file() {
  local title
  title=$(feature_title)
  printf '%s/.claude/cx/功能/%s/状态.json\n' "$PROJECT_ROOT" "$title"
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

ensure_task_exists() {
  jq -e --arg task "$TASK_ID" '.tasks[] | select((.number | tostring) == $task)' "$(feature_status_file)" >/dev/null 2>&1 \
    || die "task $TASK_ID does not exist for feature $FEATURE_SLUG"
}

verify_active_lease() {
  local lease_session
  lease_session=$(jq -r '.lease.session_id // empty' "$(core_feature_file)")
  if [[ "$ACTION" != "start" && "$lease_session" != "$SESSION_ID" ]]; then
    die "feature $FEATURE_SLUG is currently leased by $lease_session, not $SESSION_ID"
  fi
}

run_start_claim() {
  PROJECT_ROOT="$PROJECT_ROOT" bash "$SCRIPT_DIR/cx-core-worktree.sh" \
    --project-root "$PROJECT_ROOT" \
    --feature "$FEATURE_SLUG" \
    --runner "$RUNNER" \
    --session-id "$SESSION_ID" \
    --branch "$BRANCH" \
    --worktree-path "$WORKTREE_PATH" \
    --current-branch "${CURRENT_BRANCH:-$BRANCH}" \
    --current-worktree-path "${CURRENT_WORKTREE_PATH:-$WORKTREE_PATH}" >/dev/null

  PROJECT_ROOT="$PROJECT_ROOT" bash "$SCRIPT_DIR/cx-core-claim.sh" \
    --project-root "$PROJECT_ROOT" \
    --runner "$RUNNER" \
    --session-id "$SESSION_ID" \
    --branch "$BRANCH" \
    --worktree-path "$WORKTREE_PATH" \
    --feature "$FEATURE_SLUG" \
    --task "$TASK_ID" >/dev/null
}

update_status_files() {
  local now="$1"
  local action="$2"
  local task_id="$3"
  local feature_status core_feature project_status core_project
  feature_status=$(cat "$(feature_status_file)")
  core_feature=$(cat "$(core_feature_file)")
  project_status=$(cat "$(project_status_file)")
  core_project=$(cat "$(core_project_file)")

  feature_status=$(jq \
    --arg action "$action" \
    --arg task "$task_id" \
    --arg now "$now" \
    --arg commit "${COMMIT_SHA:-}" \
    --arg reason_type "${REASON_TYPE:-}" \
    --arg message "${MESSAGE:-}" \
    '
      def task_matches($target): ((.number | tostring) == $target);
      def task_state($all_tasks; $task_no):
        first($all_tasks[] | select((.number | tostring) == ($task_no | tostring)) | .status) // "pending";
      def promote_ready:
        [ .[] | select(.status == "completed") | (.number | tostring) ] as $completed
        | map(
            if .status == "pending"
               and ((.depends_on // []) | length) > 0
               and all((.depends_on // [])[]; . as $dep | ($completed | index(($dep | tostring))) != null)
            then
              .status = "ready"
            else
              .
            end
          );
      def phase_status($phase_tasks; $all_tasks):
        if any($phase_tasks[]; task_state($all_tasks; .) == "blocked") then
          "blocked"
        elif any($phase_tasks[]; task_state($all_tasks; .) == "in_progress") then
          "in_progress"
        elif (($phase_tasks | length) > 0 and all($phase_tasks[]; task_state($all_tasks; .) == "completed")) then
          "completed"
        else
          "pending"
        end;
      .last_updated = $now
      | .tasks = (
          .tasks
          | map(
              if task_matches($task) then
                if $action == "start" then
                  .status = "in_progress" | del(.reason_type, .commit)
                elif $action == "complete" then
                  .status = "completed" | del(.reason_type) | .commit = (if $commit == "" then .commit else $commit end)
                else
                  .status = "blocked" | .reason_type = $reason_type
                end
              else
                .
              end
            )
        )
      | if $action == "complete" then
          .tasks |= promote_ready
        else
          .
        end
      | .completed = ([.tasks[] | select(.status == "completed")] | length)
      | .in_progress = ([.tasks[] | select(.status == "in_progress")] | length)
      | .phases = (
          . as $root
          | (.phases // [])
          | map(
              .status = phase_status(.tasks; $root.tasks)
            )
        )
      | if $action == "block" then
          .status = "blocked"
          | .blocked = {
              reason_type: $reason_type,
              message: $message
            }
          | .workflow.current_phase = "exec"
          | .workflow.completion_status = "blocked"
          | .workflow.next_route = "cx-status"
          | .workflow.decision_basis = $message
          | .workflow.last_transition_at = $now
        else
          .
        end
      | if $action == "start" then
          .status = "executing"
          | del(.blocked)
          | .workflow.current_phase = "exec"
          | .workflow.completion_status = "ready"
          | .workflow.next_route = "cx-exec"
          | .workflow.decision_basis = "执行已开始。"
          | .workflow.last_transition_at = $now
        elif $action == "complete" then
          if (.completed == .total) then
            .status = "completed"
            | .in_progress = 0
            | del(.blocked)
            | .workflow.current_phase = "exec"
            | .workflow.completion_status = "ready"
            | .workflow.next_route = "cx-summary"
            | .workflow.decision_basis = "全部任务已完成，等待闭环。"
            | .workflow.last_transition_at = $now
          else
            .status = "executing"
            | del(.blocked)
            | .workflow.current_phase = "exec"
            | .workflow.completion_status = "ready"
            | .workflow.next_route = "cx-exec"
            | .workflow.decision_basis = "当前任务已完成，仍有剩余任务待执行。"
            | .workflow.last_transition_at = $now
          end
        else
          .
        end
    ' <<< "$feature_status")

  core_feature=$(jq \
    --arg action "$action" \
    --arg task "$task_id" \
    --arg now "$now" \
    --arg commit "${COMMIT_SHA:-}" \
    --arg reason_type "${REASON_TYPE:-}" \
    --arg message "${MESSAGE:-}" \
    --arg runner "$RUNNER" \
    --arg session "$SESSION_ID" \
    '
      def task_matches($target): ((.id | tostring) == $target);
      def promote_ready:
        [ .[] | select(.status == "completed") | (.id | tostring) ] as $completed
        | map(
            if .status == "pending"
               and ((.depends_on // []) | length) > 0
               and all((.depends_on // [])[]; . as $dep | ($completed | index(($dep | tostring))) != null)
            then
              .status = "ready"
            else
              .
            end
          );
      .lifecycle.updated_at = $now
      | .execution_owner = {runner: $runner, session_id: $session}
      | .workflow.current_phase = "exec"
      | .workflow.last_transition_at = $now
      | .tasks = (
          .tasks
          | map(
              if task_matches($task) then
                if $action == "start" then
                  .status = "in_progress" | .owner_session_id = $session
                elif $action == "complete" then
                  .status = "completed"
                else
                  .status = "blocked" | .owner_session_id = $session
                end
              else
                .
              end
            )
        )
      | if $action == "complete" then
          .tasks = (
            .tasks | promote_ready
          )
        else
          .
        end
      | .lease.last_heartbeat = $now
      | .lease.claimed_tasks = (
          [.tasks[] | select((.status == "claimed" or .status == "in_progress" or .status == "blocked") and .owner_session_id == $session) | .id]
        )
      | if $action == "block" then
          .lifecycle.stage = "blocked"
          | .lifecycle.blocked_reason = $message
          | .workflow.completion_status = "blocked"
          | .workflow.next_route = "cx-status"
          | .workflow.decision_basis = $message
        elif $action == "complete" then
          if ([.tasks[] | select(.status == "completed")] | length) == ([.tasks[]] | length) then
            .lifecycle.stage = "completed"
            | .workflow.completion_status = "ready"
            | .workflow.next_route = "cx-summary"
            | .workflow.decision_basis = "全部任务已完成，等待闭环。"
          else
            .lifecycle.stage = "executing"
            | .workflow.completion_status = "ready"
            | .workflow.next_route = "cx-exec"
            | .workflow.decision_basis = "当前任务已完成，仍有剩余任务待执行。"
          end
        else
          .lifecycle.stage = "executing"
          | .workflow.completion_status = "ready"
          | .workflow.next_route = "cx-exec"
          | .workflow.decision_basis = "执行已开始。"
        end
    ' <<< "$core_feature")

  project_status=$(jq \
    --arg slug "$FEATURE_SLUG" \
    --arg now "$now" \
    --arg status "$(jq -r '.status' <<< "$feature_status")" '
      .last_updated = $now
      | .current_feature = $slug
      | .features[$slug].status = $status
      | .features[$slug].last_updated = $now
    ' <<< "$project_status")

  core_project=$(jq \
    --arg slug "$FEATURE_SLUG" \
    --arg now "$now" \
    --arg session "$SESSION_ID" \
    --arg lifecycle "$(jq -r '.lifecycle.stage' <<< "$core_feature")" \
    --arg next_route "$(jq -r '.workflow.next_route' <<< "$core_feature")" \
    --argjson claimed_tasks "$(jq '.lease.claimed_tasks' <<< "$core_feature")" '
      .current_feature = $slug
      | .features[$slug].lifecycle = $lifecycle
      | .features[$slug].lease_session_id = $session
      | .features[$slug].workflow_phase = "exec"
      | .features[$slug].next_route = $next_route
      | .features[$slug].last_updated = $now
      | .active_sessions[$session].last_heartbeat = $now
      | .active_sessions[$session].claimed_feature = $slug
      | .active_sessions[$session].claimed_tasks = $claimed_tasks
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
  ensure_task_exists

  local now
  now=$(now_iso)

  if [[ "$ACTION" == "start" ]]; then
    run_start_claim
  else
    verify_active_lease
  fi

  update_status_files "$now" "$ACTION" "$TASK_ID"

  printf 'feature_slug=%s\n' "$FEATURE_SLUG"
  printf 'task_id=%s\n' "$TASK_ID"
  printf 'action=%s\n' "$ACTION"
  printf 'runner=%s\n' "$RUNNER"
}

main "$@"
