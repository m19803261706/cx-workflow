#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
PROJECT_FILE="${PROJECT_FILE:-}"
SOURCE_RUNNER=""
SOURCE_SESSION_ID=""
TARGET_RUNNER=""
TARGET_SESSION_ID=""
FEATURE_SLUG=""
HANDOFF_REASON=""
FORCE="false"

usage() {
  cat <<'EOF'
usage: cx-core-handoff.sh --source-runner <cx|cc|codex> --source-session-id <id> --target-runner <cx|cc|codex> --target-session-id <id> --feature <slug> --reason <text> [--force]

Append a handoff record and transfer the feature lease to the target session.
EOF
}

die() {
  echo "[handoff] $*" >&2
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
      --source-runner)
        SOURCE_RUNNER="$2"
        shift 2
        ;;
      --source-session-id)
        SOURCE_SESSION_ID="$2"
        shift 2
        ;;
      --target-runner)
        TARGET_RUNNER="$2"
        shift 2
        ;;
      --target-session-id)
        TARGET_SESSION_ID="$2"
        shift 2
        ;;
      --feature)
        FEATURE_SLUG="$2"
        shift 2
        ;;
      --reason)
        HANDOFF_REASON="$2"
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
  [[ -n "$SOURCE_RUNNER" ]] || die "--source-runner is required"
  [[ -n "$SOURCE_SESSION_ID" ]] || die "--source-session-id is required"
  [[ -n "$TARGET_RUNNER" ]] || die "--target-runner is required"
  [[ -n "$TARGET_SESSION_ID" ]] || die "--target-session-id is required"
  [[ -n "$FEATURE_SLUG" ]] || die "--feature is required"
  [[ -n "$HANDOFF_REASON" ]] || die "--reason is required"
  case "$SOURCE_RUNNER" in
    cx|cc|codex) ;;
    *) die "--source-runner must be cx, cc, or codex" ;;
  esac
  case "$TARGET_RUNNER" in
    cx|cc|codex) ;;
    *) die "--target-runner must be cx, cc, or codex" ;;
  esac
  [[ "$SOURCE_SESSION_ID" != "$TARGET_SESSION_ID" ]] || die "source and target session ids must differ"
}

ensure_parent_dir() {
  mkdir -p "$(dirname "$1")"
}

main() {
  parse_args "$@"
  require_arguments

  local project_file project_json feature_rel_path feature_file now handoff_stamp handoff_root source_session_file target_session_file
  local source_session_json target_session_json existing_lease_session existing_target_feature source_claimed_tasks_json
  local handoff_record_path

  project_file=$(find_project_file)
  project_json=$(cat "$project_file")
  feature_rel_path=$(jq -re --arg feature "$FEATURE_SLUG" '.features[$feature].path' <<< "$project_json") || die "feature $FEATURE_SLUG is missing from project registry"
  feature_file=$(resolve_path "$feature_rel_path")
  [[ -f "$feature_file" ]] || die "feature file not found: $feature_file"

  handoff_root=$(jq -r '.runtime_roots.handoffs // ".claude/cx/core/handoffs"' <<< "$project_json")
  handoff_root=$(resolve_path "$handoff_root")
  source_session_file=$(jq -r '.runtime_roots.sessions // ".claude/cx/core/sessions"' <<< "$project_json")
  source_session_file=$(resolve_path "$source_session_file")/$SOURCE_SESSION_ID.json
  target_session_file=$(jq -r '.runtime_roots.sessions // ".claude/cx/core/sessions"' <<< "$project_json")
  target_session_file=$(resolve_path "$target_session_file")/$TARGET_SESSION_ID.json

  [[ -f "$source_session_file" ]] || die "source session file not found: $source_session_file"
  [[ -f "$target_session_file" ]] || die "target session file not found: $target_session_file"

  now=$(now_iso)
  handoff_stamp=$(date -u +%Y%m%dT%H%M%SZ)

  source_session_json=$(cat "$source_session_file")
  target_session_json=$(cat "$target_session_file")
  existing_lease_session=$(jq -r --arg feature "$FEATURE_SLUG" '.features[$feature].lease_session_id // empty' <<< "$project_json")
  existing_target_feature=$(jq -r '.claimed_feature // empty' <<< "$target_session_json")

  if [[ "$existing_lease_session" != "$SOURCE_SESSION_ID" && "$FORCE" != "true" ]]; then
    die "feature $FEATURE_SLUG is not leased by source session $SOURCE_SESSION_ID"
  fi

  if [[ "$existing_target_feature" != "" && "$existing_target_feature" != "$FEATURE_SLUG" && "$FORCE" != "true" ]]; then
    die "target session $TARGET_SESSION_ID already owns feature $existing_target_feature"
  fi

  source_claimed_tasks_json=$(jq -c '.claimed_tasks // []' <<< "$source_session_json")

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  handoff_record_path=".claude/cx/core/handoffs/$FEATURE_SLUG/$handoff_stamp-$SOURCE_SESSION_ID-to-$TARGET_SESSION_ID.json"

  jq \
    --arg runner "$SOURCE_RUNNER" \
    --arg session "$SOURCE_SESSION_ID" \
    --arg branch "$(jq -r '.branch' <<< "$source_session_json")" \
    --arg worktree "$(jq -r '.worktree_path' <<< "$source_session_json")" \
    --arg feature "$FEATURE_SLUG" \
    --arg reason "$HANDOFF_REASON" \
    --arg created_at "$now" \
    --arg accepted_at "$now" \
    --arg target_runner "$TARGET_RUNNER" \
    --arg target_session_id "$TARGET_SESSION_ID" \
    --arg handoff_record_path "$handoff_record_path" \
    --argjson tasks "$source_claimed_tasks_json" '
      {
        runner: $runner,
        session_id: $session,
        branch: $branch,
        worktree_path: $worktree,
        claimed_feature: $feature,
        claimed_tasks: $tasks,
        handoff_reason: $reason,
        created_at: $created_at,
        accepted_at: $accepted_at,
        target_runner: $target_runner,
        target_session_id: $target_session_id,
        record_path: $handoff_record_path,
        acceptance_note: "lease transferred by cx-core-handoff"
      }
    ' /dev/null > "$TMP_DIR/handoff.json"

  # DEPRECATED: current_feature is a hint for non-worktree fallback.
  # Primary feature context comes from worktree branch name.
  jq \
    --arg feature "$FEATURE_SLUG" \
    --arg now "$now" \
    --arg source_runner "$SOURCE_RUNNER" \
    --arg source_session "$SOURCE_SESSION_ID" \
    --arg target_runner "$TARGET_RUNNER" \
    --arg target_session "$TARGET_SESSION_ID" \
    --argjson tasks "$source_claimed_tasks_json" \
    --arg handoff_record_path "$handoff_record_path" '
      .current_feature = $feature
      | .features[$feature].lifecycle = "executing"
      | .features[$feature].last_updated = $now
      | .features[$feature].worktree_path = (.active_sessions[$target_session].worktree_path // .features[$feature].worktree_path)
      | .features[$feature].lease_session_id = $target_session
      | .active_sessions[$source_session] = {
          runner: $source_runner,
          session_id: $source_session,
          branch: .active_sessions[$source_session].branch,
          worktree_path: .active_sessions[$source_session].worktree_path,
          started_at: .active_sessions[$source_session].started_at,
          last_heartbeat: $now,
          claimed_feature: null,
          claimed_tasks: []
        }
      | .active_sessions[$target_session] = {
          runner: $target_runner,
          session_id: $target_session,
          branch: .active_sessions[$target_session].branch,
          worktree_path: .active_sessions[$target_session].worktree_path,
          started_at: .active_sessions[$target_session].started_at,
          last_heartbeat: $now,
          claimed_feature: $feature,
          claimed_tasks: $tasks
        }
      | .features[$feature].lease_session_id = $target_session
    ' "$project_file" > "$TMP_DIR/project.json"

  jq \
    --arg feature "$FEATURE_SLUG" \
    --arg now "$now" \
    --arg source_runner "$SOURCE_RUNNER" \
    --arg source_session "$SOURCE_SESSION_ID" \
    --arg target_runner "$TARGET_RUNNER" \
    --arg target_session "$TARGET_SESSION_ID" \
    --arg branch "$(jq -r '.branch' <<< "$target_session_json")" \
    --arg worktree "$(jq -r '.worktree_path' <<< "$target_session_json")" \
    --arg handoff_record_path "$handoff_record_path" \
    --arg source_handoff_reason "$HANDOFF_REASON" \
    --argjson tasks "$source_claimed_tasks_json" '
      .lifecycle.stage = "executing"
      | .lifecycle.updated_at = $now
      | .worktree.branch = $branch
      | .worktree.worktree_path = $worktree
      | .worktree.binding_status = "bound"
      | .worktree.bound_at = $now
      | .execution_owner = {runner: $target_runner, session_id: $target_session}
      | .lease = {
          runner: $target_runner,
          session_id: $target_session,
          branch: $branch,
          worktree_path: $worktree,
          claimed_feature: $feature,
          claimed_tasks: $tasks,
          claimed_at: $now,
          last_heartbeat: $now,
          expires_at: (.lease.expires_at // $now)
        }
      | .tasks = (.tasks | map(. as $task
          | if any($tasks[]; tostring == ($task.id | tostring)) then
              $task | .owner_session_id = $target_session
            else
              $task
            end
        ))
      | .handoffs = (.handoffs + [{
          runner: $source_runner,
          session_id: $source_session,
          handoff_reason: $source_handoff_reason,
          created_at: $now,
          accepted_at: $now,
          record_path: $handoff_record_path
        }])
    ' "$feature_file" > "$TMP_DIR/feature.updated.json"

  jq \
    --arg feature "$FEATURE_SLUG" \
    --arg source_runner "$SOURCE_RUNNER" \
    --arg source_session "$SOURCE_SESSION_ID" \
    --arg now "$now" \
    --argjson tasks '[]' '
      .runner = $source_runner
      | .session_id = $source_session
      | .last_heartbeat = $now
      | .claimed_feature = null
      | .claimed_tasks = $tasks
      | .state = "handoff_pending"
    ' "$source_session_file" > "$TMP_DIR/source-session.json"

  jq \
    --arg feature "$FEATURE_SLUG" \
    --arg target_runner "$TARGET_RUNNER" \
    --arg target_session "$TARGET_SESSION_ID" \
    --arg now "$now" \
    --argjson tasks "$source_claimed_tasks_json" '
      .runner = $target_runner
      | .session_id = $target_session
      | .last_heartbeat = $now
      | .claimed_feature = $feature
      | .claimed_tasks = $tasks
      | .state = "active"
    ' "$target_session_file" > "$TMP_DIR/target-session.json"

  ensure_parent_dir "$project_file"
  ensure_parent_dir "$source_session_file"
  ensure_parent_dir "$target_session_file"
  ensure_parent_dir "$handoff_root/$FEATURE_SLUG/$handoff_stamp-$SOURCE_SESSION_ID-to-$TARGET_SESSION_ID.json"

  mv "$TMP_DIR/project.json" "$project_file"
  mv "$TMP_DIR/feature.updated.json" "$feature_file"
  mv "$TMP_DIR/source-session.json" "$source_session_file"
  mv "$TMP_DIR/target-session.json" "$target_session_file"
  mv "$TMP_DIR/handoff.json" "$handoff_root/$FEATURE_SLUG/$handoff_stamp-$SOURCE_SESSION_ID-to-$TARGET_SESSION_ID.json"

  echo "[handoff] appended record $handoff_record_path"
  echo "[handoff] transferred $FEATURE_SLUG from $SOURCE_SESSION_ID to $TARGET_SESSION_ID"
}

main "$@"
