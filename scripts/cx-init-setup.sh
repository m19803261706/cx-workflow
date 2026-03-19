#!/bin/bash
set -euo pipefail

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
PLUGIN_DIR=""

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

Initialize cx-workflow 3.0 for a project.

OPTIONS:
  --developer-id <id>          (required) Per-project developer display name
  --github-sync <mode>         GitHub sync mode: off, local, collab, full
  --agent-teams <bool>         Enable agent teams: true / false
  --code-review <bool>         Enable post-exec code review: true / false
  --worktree-isolation <bool>  Prefer git worktrees: true / false
  --auto-memory <bool>         Enable workflow memory artifacts: true / false
  --plugin-dir <path>          (required) Path to cx-workflow plugin root
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
      --plugin-dir)
        PLUGIN_DIR="$2"
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

  if [[ -z "$PLUGIN_DIR" || ! -d "$PLUGIN_DIR" ]]; then
    log_error "Missing or invalid --plugin-dir"
    exit 1
  fi
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
  local cx_root="$PROJECT_ROOT/.claude/cx"

  log_info "Creating cx 3.0 directory structure..."
  mkdir -p "$cx_root/功能"
  mkdir -p "$cx_root/修复"
  log_success "Created .claude/cx/功能 and .claude/cx/修复"
}

create_config() {
  local cx_root="$PROJECT_ROOT/.claude/cx"
  local config_file="$cx_root/配置.json"

  if [[ -f "$config_file" ]]; then
    log_warning "配置.json already exists, skipping creation"
    return
  fi

  log_info "Creating .claude/cx/配置.json..."
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
  log_success "Created .claude/cx/配置.json"
}

create_status() {
  local cx_root="$PROJECT_ROOT/.claude/cx"
  local status_file="$cx_root/状态.json"
  local now

  if [[ -f "$status_file" ]]; then
    log_warning "状态.json already exists, skipping creation"
    return
  fi

  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  log_info "Creating .claude/cx/状态.json..."
  cat > "$status_file" <<EOF
{
  "initialized_at": "$now",
  "last_updated": "$now",
  "current_feature": null,
  "features": {},
  "fixes": {}
}
EOF
  log_success "Created .claude/cx/状态.json"
}

build_hooks_json() {
  cat <<EOF
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "bash $PLUGIN_DIR/hooks/session-start.sh",
        "timeout": 10
      }]
    }],
    "PreCompact": [{
      "hooks": [{
        "type": "command",
        "command": "bash $PLUGIN_DIR/hooks/pre-compact.sh",
        "timeout": 5
      }]
    }],
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "bash $PLUGIN_DIR/hooks/prompt-submit.sh",
        "timeout": 3
      }]
    }],
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "bash $PLUGIN_DIR/hooks/post-edit.sh",
        "timeout": 15
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "bash $PLUGIN_DIR/hooks/stop-check.sh",
        "timeout": 5
      }]
    }]
  }
EOF
}

install_hooks_config() {
  local claude_dir="$PROJECT_ROOT/.claude"
  local settings_file="$claude_dir/settings.json"
  local hooks_json

  mkdir -p "$claude_dir"
  hooks_json=$(build_hooks_json)

  log_info "Installing plugin-level hooks into .claude/settings.json..."

  if [[ ! -f "$settings_file" ]]; then
    cat > "$settings_file" <<EOF
{
$hooks_json
}
EOF
    log_success "Created .claude/settings.json with plugin hooks"
    return
  fi

  if grep -q '"SessionStart"' "$settings_file"; then
    log_warning ".claude/settings.json already has hook configuration, skipping merge"
    return
  fi

  local tmp_file
  tmp_file=$(mktemp)
  sed '$ s/}$/,/' "$settings_file" > "$tmp_file"
  printf '%s\n' "$hooks_json" >> "$tmp_file"
  echo "}" >> "$tmp_file"
  mv "$tmp_file" "$settings_file"
  log_success "Merged plugin hooks into .claude/settings.json"
}

update_gitignore() {
  local gitignore="$PROJECT_ROOT/.gitignore"
  local entries_to_add=(
    ".claude/cx/.prompt-submit-counter"
    ".claude/cx/context-snapshot.md"
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
  echo "  cx-workflow 3.0 Initialization"
  echo "=========================================="
  echo ""

  log_success "Project root detected: $PROJECT_ROOT"

  create_directories
  create_config
  create_status
  install_hooks_config
  update_gitignore

  echo ""
  echo "$(detect_remote_state)"
  echo "CX_INIT_SUCCESS=true"
  echo "PROJECT_ROOT=$PROJECT_ROOT"
  echo "DEVELOPER_ID=$DEVELOPER_ID"
  echo "GITHUB_SYNC=$GITHUB_SYNC"
  echo "CONFIG_FILE=$PROJECT_ROOT/.claude/cx/配置.json"
  echo "STATUS_FILE=$PROJECT_ROOT/.claude/cx/状态.json"
  echo ""
}

main "$@"
