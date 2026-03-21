#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/cx-lib.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ROOT=""
DEVELOPER_ID=""
GITHUB_SYNC="local"
AGENT_TEAMS="true"
CODE_REVIEW="true"
WORKTREE_ISOLATION="true"
AUTO_MEMORY="true"

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
  echo -e "${RED}✗${NC} $1"
}

log_info() {
  echo "  $1"
}

show_help() {
  cat <<EOF
usage: cx-init-setup.sh [OPTIONS]

Initialize cx 3.1 for a project.

OPTIONS:
  --developer-id <id>          (required) Per-project developer display name
  --github-sync <mode>         GitHub sync mode: off, local, collab, full
  --agent-teams <bool>         Enable agent teams: true / false
  --code-review <bool>         Enable post-exec code review: true / false
  --worktree-isolation <bool>  Prefer git worktrees: true / false
  --auto-memory <bool>         Enable workflow memory artifacts: true / false
  --help                       Show this help message
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --developer-id)
        DEVELOPER_ID="$2"
        shift 2
        ;;
      --github-sync)
        GITHUB_SYNC="$2"
        shift 2
        ;;
      --agent-teams)
        AGENT_TEAMS="$2"
        shift 2
        ;;
      --code-review)
        CODE_REVIEW="$2"
        shift 2
        ;;
      --worktree-isolation)
        WORKTREE_ISOLATION="$2"
        shift 2
        ;;
      --auto-memory)
        AUTO_MEMORY="$2"
        shift 2
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

validate_bool() {
  case "$1" in
    true|false) ;;
    *)
      log_error "Invalid boolean value: $1"
      exit 1
      ;;
  esac
}

validate_arguments() {
  if [[ -z "$DEVELOPER_ID" ]]; then
    log_error "Missing required parameter: --developer-id"
    exit 1
  fi

  if [[ ! "$GITHUB_SYNC" =~ ^(off|local|collab|full)$ ]]; then
    log_error "Invalid github-sync mode: $GITHUB_SYNC"
    exit 1
  fi

  validate_bool "$AGENT_TEAMS"
  validate_bool "$CODE_REVIEW"
  validate_bool "$WORKTREE_ISOLATION"
  validate_bool "$AUTO_MEMORY"

}

detect_project_root() {
  if PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
    return
  fi

  PROJECT_ROOT=$(pwd)
  log_warning "Not a git repository, using current directory"
}

detect_remote_state() {
  if git -C "$PROJECT_ROOT" remote get-url origin >/dev/null 2>&1; then
    echo "HAS_REMOTE=true"
  else
    echo "HAS_REMOTE=false"
  fi
}

create_directories() {
  local docs_root machine_root

  docs_root=$(cx_docs_root "$PROJECT_ROOT")
  machine_root=$(cx_machine_root "$PROJECT_ROOT")

  log_info "Creating cx directory structure..."
  mkdir -p "$docs_root/功能"
  mkdir -p "$docs_root/修复"
  mkdir -p "$machine_root/core/projects"
  mkdir -p "$machine_root/core/features"
  mkdir -p "$machine_root/core/worktrees"
  mkdir -p "$machine_root/core/sessions"
  mkdir -p "$machine_root/core/handoffs"
  mkdir -p "$machine_root/runtime/cc"
  mkdir -p "$machine_root/runtime/codex"
  mkdir -p "$machine_root/runtime/cx"
  log_success "Created 开发文档/CX工作流 and .cx runtime roots"
}

create_config() {
  local config_file
  config_file=$(cx_public_config_file "$PROJECT_ROOT")

  if [[ -f "$config_file" ]]; then
    log_warning "配置.json already exists, skipping creation"
    return
  fi

  log_info "Creating 开发文档/CX工作流/配置.json..."
  cat > "$config_file" <<EOF
{
  "version": "3.0",
  "developer_id": "$DEVELOPER_ID",
  "github_sync": "$GITHUB_SYNC",
  "current_feature": "",
  "agent_teams": $AGENT_TEAMS,
  "code_review": $CODE_REVIEW,
  "auto_memory": $AUTO_MEMORY,
  "worktree_isolation": $WORKTREE_ISOLATION,
  "auto_format": {
    "enabled": true,
    "formatter": "auto"
  },
  "hooks": {
    "session_start": true,
    "pre_compact": true,
    "post_edit_format": true,
    "notification": true
  }
}
EOF
  log_success "Created 开发文档/CX工作流/配置.json"
}

create_status() {
  local status_file
  local now

  status_file=$(cx_public_status_file "$PROJECT_ROOT")

  if [[ -f "$status_file" ]]; then
    log_warning "状态.json already exists, skipping creation"
    return
  fi

  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  log_info "Creating 开发文档/CX工作流/状态.json..."
  cat > "$status_file" <<EOF
{
  "initialized_at": "$now",
  "last_updated": "$now",
  "current_feature": null,
  "features": {},
  "fixes": {}
}
EOF
  log_success "Created 开发文档/CX工作流/状态.json"
}

create_core_project_registry() {
  local project_file
  project_file="$(cx_core_projects_root "$PROJECT_ROOT")/project.json"

  if [[ -f "$project_file" ]]; then
    log_warning ".cx/core/projects/project.json already exists, skipping creation"
    return
  fi

  log_info "Creating .cx/core/projects/project.json..."
  cat > "$project_file" <<EOF
{
  "version": "1.0",
  "current_feature": null,
  "features": {},
  "active_sessions": {},
  "runtime_roots": {
    "projects": ".cx/core/projects",
    "features": ".cx/core/features",
    "sessions": ".cx/core/sessions",
    "handoffs": ".cx/core/handoffs",
    "worktrees": ".cx/core/worktrees",
    "artifacts": {
      "cx": ".cx/runtime/cx",
      "cc": ".cx/runtime/cc",
      "codex": ".cx/runtime/codex"
    }
  }
}
EOF
  log_success "Created .cx/core/projects/project.json"
}

update_gitignore() {
  local gitignore="$PROJECT_ROOT/.gitignore"
  local entries_to_add=(
    ".cx/runtime/"
    ".cx/core/sessions/"
    ".cx/core/handoffs/"
  )

  if [[ ! -f "$gitignore" ]]; then
    return
  fi

  local entries_added=0
  for entry in "${entries_to_add[@]}"; do
    if ! grep -Fxq "$entry" "$gitignore"; then
      echo "$entry" >> "$gitignore"
      entries_added=$((entries_added + 1))
    fi
  done

  if [[ $entries_added -gt 0 ]]; then
    log_success "Updated .gitignore with runtime-only cx artifacts"
  fi
}

main() {
  parse_arguments "$@"
  validate_arguments
  detect_project_root

  echo ""
  echo "=========================================="
  echo "  cx 3.1 Initialization"
  echo "=========================================="
  echo ""

  log_success "Project root detected: $PROJECT_ROOT"

  create_directories
  create_config
  create_status
  create_core_project_registry
  update_gitignore

  echo ""
  echo "$(detect_remote_state)"
  echo "CX_INIT_SUCCESS=true"
  echo "PROJECT_ROOT=$PROJECT_ROOT"
  echo "DEVELOPER_ID=$DEVELOPER_ID"
  echo "GITHUB_SYNC=$GITHUB_SYNC"
  echo "CONFIG_FILE=$(cx_public_config_file "$PROJECT_ROOT")"
  echo "STATUS_FILE=$(cx_public_status_file "$PROJECT_ROOT")"
  echo "DOCS_ROOT=$(cx_docs_root "$PROJECT_ROOT")"
  echo "MACHINE_ROOT=$(cx_machine_root "$PROJECT_ROOT")"
  echo "HOOKS_MODE=plugin-managed"
  echo ""
}

main "$@"
