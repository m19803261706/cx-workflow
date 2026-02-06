#!/bin/bash

# Hook: PostToolUse
# Purpose: Auto-format files after edit/write based on file type
# Runs async (won't block Claude)
# Respects config.auto_format.enabled setting

set -e

# Anchor to project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
CX_DIR="${PROJECT_ROOT}/.claude/cx"
CONFIG_FILE="${CX_DIR}/config.json"

# Check if config exists and auto_format is enabled
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

AUTO_FORMAT_ENABLED=$(grep -o '"auto_format"\s*:\s*{[^}]*"enabled"\s*:\s*true' "$CONFIG_FILE" 2>/dev/null || echo "")

if [[ -z "$AUTO_FORMAT_ENABLED" ]]; then
  exit 0
fi

# Read the last edited file path from environment variable (set by Claude Code)
# The PostToolUse hook passes the file path via EDITED_FILE environment variable
EDITED_FILE="${EDITED_FILE:-}"

# If no file provided, try to infer from common patterns
if [[ -z "$EDITED_FILE" ]]; then
  exit 0
fi

# Check if file exists
if [[ ! -f "$EDITED_FILE" ]]; then
  exit 0
fi

# Get file extension
FILE_EXT="${EDITED_FILE##*.}"

# Determine formatter and run it
case "$FILE_EXT" in
  js|ts|jsx|tsx|json|css|md)
    # Try prettier
    if command -v prettier &>/dev/null; then
      prettier --write "$EDITED_FILE" &>/dev/null &
    fi
    ;;
  py)
    # Try black
    if command -v black &>/dev/null; then
      black "$EDITED_FILE" &>/dev/null &
    fi
    ;;
  go)
    # Try gofmt
    if command -v gofmt &>/dev/null; then
      gofmt -w "$EDITED_FILE" &>/dev/null &
    fi
    ;;
  rs)
    # Try rustfmt
    if command -v rustfmt &>/dev/null; then
      rustfmt "$EDITED_FILE" &>/dev/null &
    fi
    ;;
  *)
    # Unknown file type, skip
    exit 0
    ;;
esac

exit 0
