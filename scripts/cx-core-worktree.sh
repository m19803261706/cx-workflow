#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/cx-lib.sh"

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
PROJECT_FILE="${PROJECT_FILE:-}"
RUNNER=""
SESSION_ID=""
FEATURE_SLUG=""
BRANCH=""
WORKTREE_PATH=""
CURRENT_BRANCH=""
CURRENT_WORKTREE_PATH=""
FORCE="false"

usage() {
  cat <<'EOF'
usage: cx-core-worktree.sh --feature <slug> [--runner <cx|cc|codex>] [--session-id <id>] [--branch <branch>] [--worktree-path <path>] [--current-branch <branch>] [--current-worktree-path <path>] [--force]

Recommend or bind the preferred worktree for a feature.
EOF
}

die() {
  echo "[worktree] $*" >&2
  exit 1
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
    cx_resolve_path "$PROJECT_FILE" "$PROJECT_ROOT"
    return
  fi

  local candidate=""
  candidate=$(cx_core_project_file "$PROJECT_ROOT")
  if [[ -n "$candidate" && -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return
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
      --feature)
        FEATURE_SLUG="$2"
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
  [[ -n "$FEATURE_SLUG" ]] || die "--feature is required"
  if [[ -n "$RUNNER" ]]; then
    case "$RUNNER" in
      cx|cc|codex) ;;
      *) die "--runner must be cx, cc, or codex" ;;
    esac
  fi
}

detect_current_worktree_path() {
  if [[ -n "$CURRENT_WORKTREE_PATH" ]]; then
    printf '%s\n' "$CURRENT_WORKTREE_PATH"
    return
  fi

  local detected=""
  if detected=$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null); then
    printf '%s\n' "$detected"
    return
  fi

  if detected=$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null); then
    printf '%s\n' "$detected"
    return
  fi

  if [[ -d "$PROJECT_ROOT" ]]; then
    (cd "$PROJECT_ROOT" && pwd -P)
    return
  fi

  pwd -P
}

detect_current_branch() {
  if [[ -n "$CURRENT_BRANCH" ]]; then
    printf '%s\n' "$CURRENT_BRANCH"
    return
  fi

  git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || true
}

ensure_parent_dir() {
  mkdir -p "$(dirname "$1")"
}

main() {
  parse_args "$@"
  require_arguments

  local project_file project_json feature_rel_path feature_file worktree_root worktree_file now record_path
  local feature_json existing_worktree_path existing_worktree_branch existing_binding_status existing_lease_session
  local recommended_worktree_path recommended_branch current_worktree_path current_branch
  local binding_status bound_at target_worktree_path target_branch target_runner target_session

  project_file=$(find_project_file)
  project_json=$(cat "$project_file")
  feature_rel_path=$(jq -re --arg feature "$FEATURE_SLUG" '.features[$feature].path' <<< "$project_json") \
    || die "feature $FEATURE_SLUG is missing from project registry"
  feature_file=$(cx_resolve_path "$feature_rel_path" "$PROJECT_ROOT")
  [[ -f "$feature_file" ]] || die "feature file not found: $feature_file"

  worktree_root=$(jq -r --arg fallback ".cx/core/worktrees" '.runtime_roots.worktrees // $fallback' <<< "$project_json")
  worktree_root=$(cx_resolve_path "$worktree_root" "$PROJECT_ROOT")
  worktree_file="$worktree_root/$FEATURE_SLUG.json"
  record_path=$(cx_relative_path "$worktree_file" "$PROJECT_ROOT")

  feature_json=$(cat "$feature_file")
  existing_worktree_path=$(jq -r '.worktree.worktree_path // empty' <<< "$feature_json")
  existing_worktree_branch=$(jq -r '.worktree.branch // empty' <<< "$feature_json")
  existing_binding_status=$(jq -r '.worktree.binding_status // "unbound"' <<< "$feature_json")
  existing_lease_session=$(jq -r --arg feature "$FEATURE_SLUG" '.features[$feature].lease_session_id // empty' <<< "$project_json")

  recommended_worktree_path="${WORKTREE_PATH:-}"
  if [[ -z "$recommended_worktree_path" ]]; then
    if [[ -n "$existing_worktree_path" ]]; then
      recommended_worktree_path="$existing_worktree_path"
    else
      recommended_worktree_path="/worktrees/$FEATURE_SLUG"
    fi
  fi

  recommended_branch="${BRANCH:-}"
  if [[ -z "$recommended_branch" ]]; then
    if [[ -n "$existing_worktree_branch" ]]; then
      recommended_branch="$existing_worktree_branch"
    elif [[ -n "$RUNNER" ]]; then
      recommended_branch="$RUNNER/$FEATURE_SLUG"
    else
      recommended_branch="feature/$FEATURE_SLUG"
    fi
  fi

  current_worktree_path=$(detect_current_worktree_path)
  current_branch=$(detect_current_branch)
  now=$(now_iso)

  if [[ -n "$RUNNER" && -z "$SESSION_ID" ]]; then
    die "--session-id is required when --runner is provided"
  fi

  if [[ -n "$RUNNER" && -n "$SESSION_ID" ]]; then
    target_runner="$RUNNER"
    target_session="$SESSION_ID"
    target_worktree_path="${recommended_worktree_path}"
    target_branch="${recommended_branch}"

    if [[ -n "$existing_worktree_path" && "$current_worktree_path" != "$existing_worktree_path" && "$FORCE" != "true" ]]; then
      die "feature $FEATURE_SLUG is bound to worktree $existing_worktree_path, but runner is in $current_worktree_path"
    fi

    if [[ "$existing_binding_status" == "bound" && -n "$existing_worktree_branch" && -n "$current_branch" && "$current_branch" != "$existing_worktree_branch" && "$FORCE" != "true" ]]; then
      die "feature $FEATURE_SLUG is bound to branch $existing_worktree_branch, but runner is on $current_branch"
    fi

    if [[ -n "$existing_lease_session" && "$existing_lease_session" != "$SESSION_ID" && "$FORCE" != "true" ]]; then
      die "feature $FEATURE_SLUG is leased by session $existing_lease_session"
    fi

    if [[ -n "$current_worktree_path" && "$target_worktree_path" != "$current_worktree_path" && "$FORCE" != "true" ]]; then
      die "runner current worktree $current_worktree_path does not match feature $FEATURE_SLUG binding $target_worktree_path"
    fi

    if [[ -n "$current_branch" && "$target_branch" != "$current_branch" && "$FORCE" != "true" ]]; then
      die "runner current branch $current_branch does not match feature $FEATURE_SLUG binding $target_branch"
    fi

    binding_status="bound"
    bound_at="$now"
  else
    target_runner=""
    target_session=""
    target_worktree_path="$recommended_worktree_path"
    target_branch="$recommended_branch"
    binding_status="recommended"
    bound_at=""
  fi

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  jq -n \
    --arg feature "$FEATURE_SLUG" \
    --arg worktree "$target_worktree_path" \
    --arg branch "$target_branch" \
    --arg status "$binding_status" \
    --arg now "$now" \
    --arg bound_at "$bound_at" \
    --arg current_worktree "$current_worktree_path" \
    --arg current_branch "$current_branch" \
    --arg runner "$target_runner" \
    --arg session "$target_session" \
    --arg record_path "$record_path" '
      {
        feature_slug: $feature,
        preferred_worktree_path: $worktree,
        preferred_branch: $branch,
        binding_status: $status,
        updated_at: $now,
        bound_at: (if $bound_at == "" then null else $bound_at end),
        runner: (if $runner == "" then null else $runner end),
        session_id: (if $session == "" then null else $session end),
        current_worktree_path: (if $current_worktree == "" then null else $current_worktree end),
        current_branch: (if $current_branch == "" then null else $current_branch end),
        record_path: $record_path
      }
    ' > "$TMP_DIR/worktree.json"

  if [[ "$binding_status" == "bound" ]]; then
    jq \
      --arg branch "$target_branch" \
      --arg worktree "$target_worktree_path" \
      --arg now "$now" '
        .worktree.branch = $branch
        | .worktree.worktree_path = $worktree
        | .worktree.binding_status = "bound"
        | .worktree.bound_at = $now
      ' "$feature_file" > "$TMP_DIR/feature.json"

    jq \
      --arg feature "$FEATURE_SLUG" \
      --arg worktree "$target_worktree_path" \
      --arg now "$now" '
        .features[$feature].worktree_path = $worktree
        | .features[$feature].last_updated = $now
      ' "$project_file" > "$TMP_DIR/project.json"

    mv "$TMP_DIR/feature.json" "$feature_file"
    mv "$TMP_DIR/project.json" "$project_file"
  fi

  mv "$TMP_DIR/worktree.json" "$worktree_file"

  if [[ "$binding_status" == "bound" ]]; then
    echo "[worktree] bound feature $FEATURE_SLUG to $target_branch @ $target_worktree_path"
  else
    echo "[worktree] recommended feature $FEATURE_SLUG worktree $target_worktree_path on branch $target_branch"
  fi
  echo "[worktree] record: $worktree_file"
}

main "$@"
