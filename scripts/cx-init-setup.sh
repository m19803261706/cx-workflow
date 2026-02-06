#!/bin/bash
set -e

# cx-workflow initialization script
# Handles deterministic file-system operations during project initialization
# Called by cx-init SKILL.md

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT=""
DEVELOPER_ID=""
GITHUB_SYNC="collab"
PLUGIN_DIR=""

# Output functions
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

# Display usage
show_help() {
  cat <<EOF
usage: cx-init-setup.sh [OPTIONS]

Initialize cx-workflow plugin for a project.

OPTIONS:
  --developer-id <id>        (required) Developer identifier (e.g., cx, alice)
  --github-sync <mode>       GitHub sync mode: off, local, collab (default), full
  --plugin-dir <path>        Path to cx-workflow plugin (for copying hooks)
  --help                     Show this help message

EXAMPLE:
  cx-init-setup.sh --developer-id cx --github-sync collab --plugin-dir /path/to/cx-workflow

EOF
}

# Parse arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --developer-id)
        DEVELOPER_ID="$2"
        shift 2
        ;;
      --github-sync)
        GITHUB_SYNC="$2"
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

# Validate arguments
validate_arguments() {
  if [[ -z "$DEVELOPER_ID" ]]; then
    log_error "Missing required parameter: --developer-id"
    show_help
    exit 1
  fi

  if [[ ! "$GITHUB_SYNC" =~ ^(off|local|collab|full)$ ]]; then
    log_error "Invalid github-sync mode: $GITHUB_SYNC"
    exit 1
  fi

  if [[ -n "$PLUGIN_DIR" && ! -d "$PLUGIN_DIR" ]]; then
    log_error "Plugin directory does not exist: $PLUGIN_DIR"
    exit 1
  fi
}

# Detect project root
detect_project_root() {
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    PROJECT_ROOT=$(pwd)
    log_warning "Not a git repository, using current directory"
  }
}

# Create directory structure
create_directories() {
  local cx_root="$PROJECT_ROOT/.claude/cx"

  log_info "Creating directory structure..."
  mkdir -p "$cx_root/features"
  mkdir -p "$cx_root/fixes"
  mkdir -p "$cx_root/hooks"

  log_success "Directories created"
}

# Create config.json
create_config() {
  local cx_root="$PROJECT_ROOT/.claude/cx"
  local config_file="$cx_root/config.json"

  if [[ -f "$config_file" ]]; then
    log_warning "config.json already exists, skipping creation"
    return
  fi

  log_info "Creating config.json..."

  cat > "$config_file" <<EOF
{
  "version": "2.0",
  "developer_id": "$DEVELOPER_ID",
  "github_sync": "$GITHUB_SYNC",
  "current_feature": "",

  "agent_teams": false,
  "background_agents": false,
  "code_review": true,

  "auto_format": {
    "enabled": true,
    "formatter": "auto"
  },

  "hooks": {
    "session_start": true,
    "pre_compact": true,
    "prompt_refresh_interval": 5,
    "stop_verify": true,
    "post_edit_format": true,
    "notification": true,
    "permission_auto_approve": true
  }
}
EOF

  log_success "config.json created"
}

# Create status.json
create_status() {
  local cx_root="$PROJECT_ROOT/.claude/cx"
  local status_file="$cx_root/status.json"

  if [[ -f "$status_file" ]]; then
    log_warning "status.json already exists, skipping creation"
    return
  fi

  log_info "Creating status.json..."

  cat > "$status_file" <<EOF
{
  "features": {},
  "fixes": {}
}
EOF

  log_success "status.json created"
}

# Copy hook scripts
copy_hooks() {
  local cx_root="$PROJECT_ROOT/.claude/cx"
  local hooks_dest="$cx_root/hooks"

  if [[ -z "$PLUGIN_DIR" ]]; then
    log_warning "No plugin directory specified, skipping hook scripts"
    return
  fi

  if [[ ! -d "$PLUGIN_DIR/hooks" ]]; then
    log_warning "Plugin hooks directory not found: $PLUGIN_DIR/hooks"
    return
  fi

  log_info "Copying hook scripts..."

  # Copy all hook scripts and make them executable
  local hooks_copied=0
  for hook_script in "$PLUGIN_DIR/hooks"/*.sh; do
    if [[ -f "$hook_script" ]]; then
      local hook_name=$(basename "$hook_script")
      cp "$hook_script" "$hooks_dest/$hook_name"
      chmod +x "$hooks_dest/$hook_name"
      hooks_copied=$((hooks_copied + 1))
    fi
  done

  if [[ $hooks_copied -eq 0 ]]; then
    log_warning "No hook scripts found in $PLUGIN_DIR/hooks"
  else
    log_success "Copied $hooks_copied hook scripts"
  fi
}

# Install hooks into .claude/settings.json
install_hooks_config() {
  local settings_file="$PROJECT_ROOT/.claude/settings.json"

  log_info "Installing hooks configuration..."

  # Check if .claude directory exists
  mkdir -p "$PROJECT_ROOT/.claude"

  # Define hooks configuration
  local hooks_config=$(cat <<'HOOKS_EOF'
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/session-start.sh",
        "timeout": 10
      }]
    }],

    "PreCompact": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/pre-compact.sh",
        "timeout": 5
      }]
    }],

    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/prompt-submit.sh",
        "timeout": 3
      }]
    }],

    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/post-edit.sh",
        "timeout": 15,
        "async": true
      }]
    }],

    "Stop": [{
      "hooks": [{
        "type": "prompt",
        "prompt": "检查当前 cx-workflow 任务：读取 .claude/cx/ 下的 status.json，如果有 in_progress 的任务但用户没有明确说完成，提醒用户。如果没有活跃任务或用户已确认完成，返回 ok。"
      }]
    }],

    "SubagentStop": [{
      "hooks": [{
        "type": "prompt",
        "prompt": "检查子代理的执行结果：代码是否符合契约？测试是否通过？如果有问题返回 reject 并说明原因。"
      }]
    }],

    "Notification": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/notification.sh",
        "timeout": 3
      }]
    }],

    "PermissionRequest": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${PROJECT_ROOT}/.claude/cx/hooks/permission-auto-approve.sh",
        "timeout": 2
      }]
    }]
  }
HOOKS_EOF
)

  if [[ ! -f "$settings_file" ]]; then
    # Create new settings.json with hooks
    cat > "$settings_file" <<EOF
{
  $hooks_config
}
EOF
    log_success "Created .claude/settings.json with hooks"
  else
    # Check if hooks already exist
    if grep -q '"SessionStart"' "$settings_file"; then
      log_warning ".claude/settings.json already has hooks configuration"
      return
    fi

    # Merge hooks into existing settings.json
    # This is a simple merge - append hooks before closing brace
    if grep -q '}$' "$settings_file"; then
      # Remove trailing closing brace, add comma, add hooks, add closing brace
      sed -i '$ s/}$/,/' "$settings_file"
      echo "$hooks_config" >> "$settings_file"
      echo "}" >> "$settings_file"
      log_success "Merged hooks into .claude/settings.json"
    else
      log_warning "Could not merge hooks into .claude/settings.json (unexpected format)"
    fi
  fi
}

# Handle CLAUDE.md
handle_claude_md() {
  local claude_md="$PROJECT_ROOT/CLAUDE.md"
  local marker_start="<!-- CX-WORKFLOW-START -->"
  local marker_end="<!-- CX-WORKFLOW-END -->"

  if [[ ! -f "$claude_md" ]]; then
    echo "CLAUDE_MD_STATUS=new"
    return
  fi

  # Check for CX workflow markers
  if grep -q "$marker_start" "$claude_md"; then
    echo "CLAUDE_MD_STATUS=update"
  else
    echo "CLAUDE_MD_STATUS=append"
  fi
}

# Update .gitignore
update_gitignore() {
  local gitignore="$PROJECT_ROOT/.gitignore"
  local entries_to_add=(
    ".claude/cx/config.json"
    ".claude/cx/context-snapshot.md"
    ".claude/cx/.prompt-submit-counter"
  )

  if [[ ! -f "$gitignore" ]]; then
    log_warning "No .gitignore found, skipping gitignore update"
    return
  fi

  log_info "Updating .gitignore..."

  local entries_added=0
  for entry in "${entries_to_add[@]}"; do
    if ! grep -Fxq "$entry" "$gitignore"; then
      echo "$entry" >> "$gitignore"
      entries_added=$((entries_added + 1))
    fi
  done

  if [[ $entries_added -gt 0 ]]; then
    log_success "Added $entries_added entries to .gitignore"
  else
    log_warning "All entries already in .gitignore"
  fi
}

# Main execution
main() {
  echo ""
  echo "=========================================="
  echo "  cx-workflow Initialization"
  echo "=========================================="
  echo ""

  # Parse and validate arguments
  parse_arguments "$@"
  validate_arguments

  # Detect project root
  detect_project_root
  log_success "Project root detected: $PROJECT_ROOT"
  echo ""

  # Create structure and config
  create_directories
  create_config
  create_status
  echo ""

  # Copy hooks and install configuration
  copy_hooks
  install_hooks_config
  echo ""

  # Handle CLAUDE.md
  log_info "Checking CLAUDE.md status..."
  claude_md_status=$(handle_claude_md)
  echo ""

  # Update .gitignore
  update_gitignore
  echo ""

  # Count installed hooks
  local hooks_dir="$PROJECT_ROOT/.claude/cx/hooks"
  local hooks_count=0
  if [[ -d "$hooks_dir" ]]; then
    hooks_count=$(find "$hooks_dir" -maxdepth 1 -name "*.sh" -type f | wc -l)
  fi

  # Output summary
  echo "=========================================="
  echo "  Initialization Summary"
  echo "=========================================="
  echo ""
  log_success "cx-init-setup.sh completed successfully"
  echo ""
  echo "CX_INIT_SUCCESS=true"
  echo "PROJECT_ROOT=$PROJECT_ROOT"
  echo "DEVELOPER_ID=$DEVELOPER_ID"
  echo "GITHUB_SYNC=$GITHUB_SYNC"
  echo "$claude_md_status"
  echo "HOOKS_INSTALLED=$hooks_count"
  echo ""
}

# Run main function
main "$@"
