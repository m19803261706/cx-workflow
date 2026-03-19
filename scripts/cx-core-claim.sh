#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
PROJECT_FILE="${PROJECT_FILE:-}"
RUNNER=""
SESSION_ID=""
BRANCH=""
WORKTREE_PATH=""
FEATURE_SLUG=""
TASK_ARGS=()
FORCE="false"

usage() {
  cat <<'EOF'
usage: cx-core-claim.sh --runner <cx|cc|codex> --session-id <id> --branch <branch> --worktree-path <path> --feature <slug> [--task <id>]... [--tasks <id,id,...>] [--force]

Claim a feature lease and optionally claim tasks for the current runner session.
EOF
}

die() {
  echo "[claim] $*" >&2
  exit 1
}

resolve_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$PROJECT_ROOT" "$path"
  fi
}

now_iso() {
  if [[ -n "${CX_CORE_NOW:-}" ]]; then
    printf '%s\n' "$CX_CORE_NOW"
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

plus_hours() {
  local base="$1"
  local hours="${2:-2}"
  jq -nr --arg base "$base" --argjson hours "$hours" '$base | fromdateiso8601 + ($hours * 3600) | todateiso8601'
}

find_project_file() {
  if [[ -n "$PROJECT_FILE" ]]; then
    resolve_path "$PROJECT_FILE"
    return
  fi

  local candidate="$PROJECT_ROOT/.claude/cx/core/project.json"
  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return
  fi

  local project_dir="$PROJECT_ROOT/.claude/cx/core/projects"
  local matches=("$project_dir"/*.json)
  if [[ ${#matches[@]} -eq 1 && -f "${matches[0]}" ]]; then
    printf '%s\n' "${matches[0]}"
    return
  fi

  if [[ ${#matches[@]} -gt 1 ]]; then
    die "multiple project registry files found under $project_dir; pass --project-file"
  fi

  die "no project registry file found; pass --project-file"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-root)
        PROJECT_ROOT="$2"
        shift 2
        ;;
      --project-file)
        PROJECT_FILE="$2"
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
      --feature)
        FEATURE_SLUG="$2"
        shift 2
        ;;
      --task)
        TASK_ARGS+=("$2")
        shift 2
        ;;
      --tasks)
        IFS=, read -r -a csv_tasks <<< "$2"
        for task in "${csv_tasks[@]}"; do
          task="${task#${task%%[![:space:]]*}}"
          task="${task%${task##*[![:space:]]}}"
          if [[ -n "$task" ]]; then
            TASK_ARGS+=("$task")
          fi
        done
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

require_arguments() {
  [[ -n "$RUNNER" ]] || die "--runner is required"
  [[ -n "$SESSION_ID" ]] || die "--session-id is required"
  [[ -n "$BRANCH" ]] || die "--branch is required"
  [[ -n "$WORKTREE_PATH" ]] || die "--worktree-path is required"
  [[ -n "$FEATURE_SLUG" ]] || die "--feature is required"
  case "$RUNNER" in
    cx|cc|codex) ;;
    *) die "--runner must be cx, cc, or codex" ;;
  esac
}

task_array_json() {
  if [[ ${#TASK_ARGS[@]} -eq 0 ]]; then
    printf '[]\n'
    return
  fi

  local joined=""
  local task
  for task in "${TASK_ARGS[@]}"; do
    if [[ -n "$joined" ]]; then
      joined+=","
    fi
    joined+="$task"
  done

  jq -n --arg csv "$joined" '
    $csv
    | split(",")
    | map(gsub("^\\s+|\\s+$"; ""))
    | map(select(length > 0))
    | map(if test("^[0-9]+$") then tonumber else . end)
    | unique
  '
}

ensure_parent_dir() {
  mkdir -p "$(dirname "$1")"
}

main() {
  parse_args "$@"
  require_arguments

  local project_file
  project_file=$(find_project_file)

  local project_json
  project_json=$(cat "$project_file")

  local feature_rel_path feature_file sessions_root now expires requested_tasks_json existing_lease_session existing_session_feature existing_session_branch existing_session_worktree existing_session_started_at existing_session_file feature_json
  feature_rel_path=$(jq -re --arg feature "$FEATURE_SLUG" '.features[$feature].path' <<< "$project_json") || die "feature $FEATURE_SLUG is missing from project registry"
  feature_file=$(resolve_path "$feature_rel_path")
  [[ -f "$feature_file" ]] || die "feature file not found: $feature_file"

  sessions_root=$(jq -r '.runtime_roots.sessions // ".claude/cx/core/sessions"' <<< "$project_json")
  sessions_root=$(resolve_path "$sessions_root")
  existing_session_file="$sessions_root/$SESSION_ID.json"

  now=$(now_iso)
  expires=$(plus_hours "$now" 2)
  requested_tasks_json=$(task_array_json)

  existing_lease_session=$(jq -r --arg feature "$FEATURE_SLUG" '.features[$feature].lease_session_id // empty' <<< "$project_json")
  existing_session_feature=$(jq -r --arg session "$SESSION_ID" '.active_sessions[$session].claimed_feature // empty' <<< "$project_json")
  existing_session_branch=$(jq -r --arg session "$SESSION_ID" '.active_sessions[$session].branch // empty' <<< "$project_json")
  existing_session_worktree=$(jq -r --arg session "$SESSION_ID" '.active_sessions[$session].worktree_path // empty' <<< "$project_json")
  existing_session_started_at=$(jq -r --arg session "$SESSION_ID" '.active_sessions[$session].started_at // empty' <<< "$project_json")

  if [[ "$existing_lease_session" != "" && "$existing_lease_session" != "$SESSION_ID" && "$FORCE" != "true" ]]; then
    die "feature $FEATURE_SLUG is already leased by session $existing_lease_session"
  fi

  if [[ "$existing_session_feature" != "" && "$existing_session_feature" != "$FEATURE_SLUG" && "$FORCE" != "true" ]]; then
    die "session $SESSION_ID already owns feature $existing_session_feature"
  fi

  if [[ -f "$existing_session_file" ]]; then
    if [[ "$existing_session_branch" != "" && "$existing_session_branch" != "$BRANCH" && "$FORCE" != "true" ]]; then
      die "session $SESSION_ID already uses branch $existing_session_branch"
    fi
    if [[ "$existing_session_worktree" != "" && "$existing_session_worktree" != "$WORKTREE_PATH" && "$FORCE" != "true" ]]; then
      die "session $SESSION_ID already uses worktree $existing_session_worktree"
    fi
  fi

  if [[ "$FORCE" != "true" ]]; then
    local task task_info task_status task_owner
    for task in "${TASK_ARGS[@]}"; do
      task_info=$(jq -r --arg task "$task" '
        .tasks[]
        | select((.id | tostring) == $task)
        | [ .status, (.owner_session_id // "") ]
        | @tsv
      ' "$feature_file" | head -n 1)

      [[ -n "$task_info" ]] || die "task $task does not exist on feature $FEATURE_SLUG"

      task_status=${task_info%%$'\t'*}
      task_owner=${task_info#*$'\t'}

      if [[ "$task_owner" != "" && "$task_owner" != "$SESSION_ID" ]]; then
        die "task $task is already owned by session $task_owner"
      fi

      if [[ "$task_status" == "completed" || "$task_status" == "archived" ]]; then
        die "task $task cannot be claimed from status $task_status"
      fi
    done
  fi

  local existing_feature_tasks_json final_tasks_json target_runtime_root session_source feature_source
  existing_feature_tasks_json=$(jq -c '.lease.claimed_tasks // []' "$feature_file")
  if [[ ${#TASK_ARGS[@]} -eq 0 ]]; then
    final_tasks_json="$existing_feature_tasks_json"
  else
    final_tasks_json=$(jq -n --argjson current "$existing_feature_tasks_json" --argjson requested "$requested_tasks_json" '$current + $requested | unique')
  fi

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  target_runtime_root=$(jq -r --arg runner "$RUNNER" '.runtime_roots.artifacts[$runner] // (".claude/cx/runtime/" + $runner)' <<< "$project_json")
  session_source="$existing_session_file"
  feature_source="$feature_file"
  [[ -f "$session_source" ]] || session_source=/dev/null

  jq \
    --arg feature "$FEATURE_SLUG" \
    --arg runner "$RUNNER" \
    --arg session "$SESSION_ID" \
    --arg branch "$BRANCH" \
    --arg worktree "$WORKTREE_PATH" \
    --arg now "$now" \
    --arg expires "$expires" \
    --argjson tasks "$final_tasks_json" '
      .current_feature = $feature
      | .features[$feature].lifecycle = "executing"
      | .features[$feature].last_updated = $now
      | .features[$feature].worktree_path = $worktree
      | .features[$feature].lease_session_id = $session
      | .active_sessions[$session] = {
          runner: $runner,
          session_id: $session,
          branch: $branch,
          worktree_path: $worktree,
          started_at: (if .active_sessions[$session].started_at then .active_sessions[$session].started_at else $now end),
          last_heartbeat: $now,
          claimed_feature: $feature,
          claimed_tasks: $tasks
        }
    ' "$project_file" > "$TMP_DIR/project.json"

  if [[ -f "$existing_session_file" ]]; then
    jq \
      --arg feature "$FEATURE_SLUG" \
      --arg runner "$RUNNER" \
      --arg session "$SESSION_ID" \
      --arg branch "$BRANCH" \
      --arg worktree "$WORKTREE_PATH" \
      --arg now "$now" \
      --arg target_runtime_root "$target_runtime_root" \
      --argjson tasks "$final_tasks_json" '
        .runner = $runner
        | .session_id = $session
        | .branch = $branch
        | .worktree_path = $worktree
        | .started_at = (.started_at // $now)
        | .last_heartbeat = $now
        | .claimed_feature = $feature
        | .claimed_tasks = $tasks
        | .state = "active"
        | .runtime_artifacts = {
            root: ($target_runtime_root + "/" + $session),
            state_file: ($target_runtime_root + "/" + $session + "/session.json"),
            transcript: ($target_runtime_root + "/" + $session + "/transcript.md"),
            heartbeat_file: ($target_runtime_root + "/" + $session + "/heartbeat.json")
          }
      ' "$session_source" > "$TMP_DIR/session.updated.json"
  else
    jq -n \
      --arg feature "$FEATURE_SLUG" \
      --arg runner "$RUNNER" \
      --arg session "$SESSION_ID" \
      --arg branch "$BRANCH" \
      --arg worktree "$WORKTREE_PATH" \
      --arg now "$now" \
      --arg target_runtime_root "$target_runtime_root" \
      --argjson tasks "$final_tasks_json" '
        {
          runner: $runner,
          session_id: $session,
          branch: $branch,
          worktree_path: $worktree,
          started_at: $now,
          last_heartbeat: $now,
          claimed_feature: $feature,
          claimed_tasks: $tasks,
          state: "active",
          runtime_artifacts: {
            root: ($target_runtime_root + "/" + $session),
            state_file: ($target_runtime_root + "/" + $session + "/session.json"),
            transcript: ($target_runtime_root + "/" + $session + "/transcript.md"),
            heartbeat_file: ($target_runtime_root + "/" + $session + "/heartbeat.json")
          }
        }
      ' > "$TMP_DIR/session.updated.json"
  fi

  jq \
    --arg feature "$FEATURE_SLUG" \
    --arg runner "$RUNNER" \
    --arg session "$SESSION_ID" \
    --arg branch "$BRANCH" \
    --arg worktree "$WORKTREE_PATH" \
    --arg now "$now" \
    --arg expires "$expires" \
    --argjson tasks "$final_tasks_json" '
      .lifecycle.stage = "executing"
      | .lifecycle.updated_at = $now
      | .worktree.branch = $branch
      | .worktree.worktree_path = $worktree
      | .worktree.binding_status = "bound"
      | .worktree.bound_at = $now
      | .execution_owner = {runner: $runner, session_id: $session}
      | .lease = {
          runner: $runner,
          session_id: $session,
          branch: $branch,
          worktree_path: $worktree,
          claimed_feature: $feature,
          claimed_tasks: $tasks,
          claimed_at: $now,
          last_heartbeat: $now,
          expires_at: $expires
        }
      | .tasks = (.tasks | map(. as $task
          | if any($tasks[]; tostring == ($task.id | tostring)) then
              $task
              | .owner_session_id = $session
              | .status = (if .status == "completed" or .status == "archived" then .status else "claimed" end)
            else
              $task
            end
        ))
    ' "$feature_source" > "$TMP_DIR/feature.updated.json"

  ensure_parent_dir "$feature_file"
  ensure_parent_dir "$existing_session_file"
  ensure_parent_dir "$project_file"

  mv "$TMP_DIR/project.json" "$project_file"
  mv "$TMP_DIR/session.updated.json" "$existing_session_file"
  mv "$TMP_DIR/feature.updated.json" "$feature_file"

  echo "[claim] registered session $SESSION_ID"
  echo "[claim] leased feature $FEATURE_SLUG"
  if [[ ${#TASK_ARGS[@]} -gt 0 ]]; then
    echo "[claim] claimed tasks: ${TASK_ARGS[*]}"
  fi
}

main "$@"
