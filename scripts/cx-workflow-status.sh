#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/cx-lib.sh"

PROJECT_ROOT="${PROJECT_ROOT:-}"
FEATURE_SLUG=""
RUNNER="cx"
WRITE_SNAPSHOT="true"

usage() {
  cat <<'EOF'
usage: cx-workflow-status.sh [OPTIONS]

Read shared workflow status and optionally write a runner-specific snapshot.

OPTIONS:
  --project-root <path>         Project root
  --feature <slug>              Optional feature slug (defaults to current_feature)
  --runner <cx|cc|codex>        Runner snapshot namespace (default: cx)
  --write-snapshot <true|false> Whether to persist runtime snapshot (default: true)
  --help                        Show this help message
EOF
}

die() {
  echo "[cx-workflow-status] $*" >&2
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
      --write-snapshot)
        WRITE_SNAPSHOT="$2"
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
  case "$RUNNER" in
    cx|cc|codex) ;;
    *) die "--runner must be cx, cc, or codex" ;;
  esac

  case "$WRITE_SNAPSHOT" in
    true|false) ;;
    *) die "--write-snapshot must be true or false" ;;
  esac
}

ensure_runtime() {
  [[ -f "$PROJECT_ROOT/.claude/cx/状态.json" ]] || die "missing .claude/cx/状态.json"
  [[ -f "$PROJECT_ROOT/.claude/cx/core/projects/project.json" ]] || die "missing .claude/cx/core/projects/project.json"
}

resolve_feature_slug() {
  if [[ -n "$FEATURE_SLUG" ]]; then
    return
  fi

  FEATURE_SLUG=$(resolve_current_feature "$PROJECT_ROOT")
}

feature_title() {
  jq -r --arg slug "$FEATURE_SLUG" '.features[$slug].title // empty' "$PROJECT_ROOT/.claude/cx/状态.json"
}

feature_dir() {
  printf '%s/.claude/cx/功能/%s\n' "$PROJECT_ROOT" "$(feature_title)"
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

runtime_snapshot_file() {
  printf '%s/.claude/cx/runtime/%s/当前状态.json\n' "$PROJECT_ROOT" "$RUNNER"
}

write_empty_snapshot() {
  local now="$1"
  mkdir -p "$(dirname "$(runtime_snapshot_file)")"
  jq -n \
    --arg now "$now" \
    --arg runner "$RUNNER" \
    '{
      captured_at: $now,
      runner: $runner,
      current_feature: null,
      recommendation: "cx-prd"
    }' > "$(runtime_snapshot_file)"
}

write_feature_snapshot() {
  local now="$1"
  local feature_status core_feature core_project worktree_json
  feature_status=$(cat "$(feature_status_file)")
  core_feature=$(cat "$(core_feature_file)")
  core_project=$(cat "$PROJECT_ROOT/.claude/cx/core/projects/project.json")
  if [[ -f "$(worktree_file)" ]]; then
    worktree_json=$(cat "$(worktree_file)")
  else
    worktree_json='{}'
  fi

  mkdir -p "$(dirname "$(runtime_snapshot_file)")"
  jq -n \
    --arg now "$now" \
    --arg runner "$RUNNER" \
    --arg slug "$FEATURE_SLUG" \
    --arg title "$(feature_title)" \
    --argjson feature_status "$feature_status" \
    --argjson core_feature "$core_feature" \
    --argjson core_project "$core_project" \
    --argjson worktree "$worktree_json" \
    '{
      captured_at: $now,
      runner: $runner,
      current_feature: {
        slug: $slug,
        title: $title,
        status: $feature_status.status,
        lifecycle: $core_feature.lifecycle.stage,
        progress: {
          completed: $feature_status.completed,
          total: $feature_status.total
        },
        workflow_phase: $feature_status.workflow.current_phase,
        next_route: $feature_status.workflow.next_route,
        owner_runner: ($core_feature.execution_owner.runner // $core_feature.planning_owner.runner // null),
        owner_session_id: ($core_project.features[$slug].lease_session_id // $core_feature.execution_owner.session_id // $core_feature.planning_owner.session_id // null),
        worktree: {
          binding_status: ($worktree.binding_status // $core_feature.worktree.binding_status // null),
          preferred_worktree_path: ($worktree.preferred_worktree_path // $core_feature.worktree.worktree_path // null),
          preferred_branch: ($worktree.preferred_branch // $core_feature.worktree.branch // null)
        },
        blocked: ($feature_status.blocked // null),
        handoff_count: ($core_feature.handoffs | length)
      }
    }' > "$(runtime_snapshot_file)"
}

main() {
  parse_args "$@"
  detect_project_root
  validate_args
  ensure_runtime
  resolve_feature_slug

  local now snapshot_file
  now=$(now_iso)
  snapshot_file=$(runtime_snapshot_file)

  if [[ -z "$FEATURE_SLUG" ]]; then
    if [[ "$WRITE_SNAPSHOT" == "true" ]]; then
      write_empty_snapshot "$now"
    fi
    printf 'current_feature=\n'
    printf 'feature_status=\n'
    printf 'next_route=cx-prd\n'
    printf 'owner_runner=\n'
    printf 'owner_session_id=\n'
    printf 'worktree_path=\n'
    printf 'binding_status=\n'
    if [[ "$WRITE_SNAPSHOT" == "true" ]]; then
      printf 'snapshot_file=%s\n' "$snapshot_file"
    fi
    exit 0
  fi

  [[ -f "$(feature_status_file)" ]] || die "missing feature status for $FEATURE_SLUG"
  [[ -f "$(core_feature_file)" ]] || die "missing core feature record for $FEATURE_SLUG"

  if [[ "$WRITE_SNAPSHOT" == "true" ]]; then
    write_feature_snapshot "$now"
  fi

  printf 'current_feature=%s\n' "$FEATURE_SLUG"
  printf 'feature_title=%s\n' "$(feature_title)"
  printf 'feature_status=%s\n' "$(jq -r '.status' "$(feature_status_file)")"
  printf 'progress=%s/%s\n' "$(jq -r '.completed' "$(feature_status_file)")" "$(jq -r '.total' "$(feature_status_file)")"
  printf 'workflow_phase=%s\n' "$(jq -r '.workflow.current_phase' "$(feature_status_file)")"
  printf 'next_route=%s\n' "$(jq -r '.workflow.next_route // empty' "$(feature_status_file)")"
  printf 'owner_runner=%s\n' "$(jq -r '.execution_owner.runner // .planning_owner.runner // empty' "$(core_feature_file)")"
  printf 'owner_session_id=%s\n' "$(jq -r --arg slug "$FEATURE_SLUG" '.features[$slug].lease_session_id // empty' "$PROJECT_ROOT/.claude/cx/core/projects/project.json")"
  if [[ -f "$(worktree_file)" ]]; then
    printf 'worktree_path=%s\n' "$(jq -r '.preferred_worktree_path // empty' "$(worktree_file)")"
    printf 'binding_status=%s\n' "$(jq -r '.binding_status // empty' "$(worktree_file)")"
  else
    printf 'worktree_path=%s\n' "$(jq -r '.worktree.worktree_path // empty' "$(core_feature_file)")"
    printf 'binding_status=%s\n' "$(jq -r '.worktree.binding_status // empty' "$(core_feature_file)")"
  fi
  printf 'blocked_reason_type=%s\n' "$(jq -r '.blocked.reason_type // empty' "$(feature_status_file)")"
  printf 'blocked_message=%s\n' "$(jq -r '.blocked.message // empty' "$(feature_status_file)")"
  if [[ "$WRITE_SNAPSHOT" == "true" ]]; then
    printf 'snapshot_file=%s\n' "$snapshot_file"
  fi
}

main "$@"
