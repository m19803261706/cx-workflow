#!/bin/bash

# Hook: UserPromptSubmit
# Purpose: Inject goal refresh reminder every N invocations
# Outputs reminder only on N-th invocation, otherwise silent

set -e

# Anchor to project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
CX_DIR="${PROJECT_ROOT}/.claude/cx"
CONFIG_FILE="${CX_DIR}/config.json"

# Check if cx config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

# Read prompt refresh interval (default: 5)
REFRESH_INTERVAL=$(grep -o '"prompt_refresh_interval"\s*:\s*[0-9]*' "$CONFIG_FILE" 2>/dev/null | grep -o '[0-9]*' || echo "5")

# Track invocation count in a temp counter file
COUNTER_FILE="${CX_DIR}/.prompt-submit-counter"
mkdir -p "$CX_DIR"

# Read current counter
COUNTER=0
if [[ -f "$COUNTER_FILE" ]]; then
  COUNTER=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
fi

# Increment counter
COUNTER=$((COUNTER + 1))

# Check if we should output refresh
if [[ $((COUNTER % REFRESH_INTERVAL)) -eq 0 ]]; then
  # Read current task info
  CURRENT_FEATURE=$(grep -o '"current_feature"\s*:\s*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4 || echo "")

  if [[ -n "$CURRENT_FEATURE" ]]; then
    STATUS_FILE="${CX_DIR}/features/${CURRENT_FEATURE}/status.json"
    if [[ -f "$STATUS_FILE" ]]; then
      CURRENT_TASK=$(grep -o '"current_task"\s*:\s*[0-9]*' "$STATUS_FILE" 2>/dev/null | grep -o '[0-9]*' || echo "1")
      TOTAL_TASKS=$(grep -o '"total"\s*:\s*[0-9]*' "$STATUS_FILE" 2>/dev/null | grep -o '[0-9]*' | tail -1 || echo "0")

      # Extract task description from tasks.json if available
      TASKS_FILE="${CX_DIR}/features/${CURRENT_FEATURE}/tasks.json"
      TASK_DESC=""
      if [[ -f "$TASKS_FILE" ]]; then
        # Try to extract description for current task (simple heuristic)
        TASK_DESC=$(grep -A 2 "\"task_id\"\s*:\s*$CURRENT_TASK" "$TASKS_FILE" 2>/dev/null | grep -o '"description"\s*:\s*"[^"]*"' | cut -d'"' -f4 | head -1 || echo "")
      fi

      # Output reminder
      if [[ -z "$TASK_DESC" ]]; then
        echo "🎯 当前: $CURRENT_FEATURE — 任务 $CURRENT_TASK/$TOTAL_TASKS"
      else
        echo "🎯 当前: $CURRENT_FEATURE — 任务 $CURRENT_TASK/$TOTAL_TASKS — $TASK_DESC"
      fi
    fi
  fi
fi

# Save updated counter
echo "$COUNTER" > "$COUNTER_FILE"
