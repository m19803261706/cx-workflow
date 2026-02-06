#!/bin/bash

# Hook: SessionStart
# Purpose: Load context for current feature, check for interrupted tasks
# Outputs context summary to stdout for Claude to see

set -e

# Anchor to project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
CX_DIR="${PROJECT_ROOT}/.claude/cx"

# Check if cx config exists
if [[ ! -f "${CX_DIR}/config.json" ]]; then
  echo "无活跃任务"
  exit 0
fi

# Read current feature from config
CURRENT_FEATURE=$(grep -o '"current_feature"\s*:\s*"[^"]*"' "${CX_DIR}/config.json" 2>/dev/null | cut -d'"' -f4 || echo "")

# If no current feature, exit early
if [[ -z "$CURRENT_FEATURE" ]]; then
  echo "无活跃任务"
  exit 0
fi

# Read status.json for this feature
STATUS_FILE="${CX_DIR}/features/${CURRENT_FEATURE}/status.json"

if [[ ! -f "$STATUS_FILE" ]]; then
  echo "无活跃任务"
  exit 0
fi

# Parse status.json for progress and state
TOTAL_TASKS=$(grep -o '"total"\s*:\s*[0-9]*' "$STATUS_FILE" 2>/dev/null | grep -o '[0-9]*' | tail -1 || echo "0")
COMPLETED_TASKS=$(grep -o '"completed"\s*:\s*[0-9]*' "$STATUS_FILE" 2>/dev/null | grep -o '[0-9]*' | tail -1 || echo "0")

# Check for in_progress task
IN_PROGRESS_TASK=$(grep -o '"in_progress"\s*:\s*[0-9]*' "$STATUS_FILE" 2>/dev/null | grep -o '[0-9]*' || echo "")

# Check if summary_done exists
SUMMARY_DONE=$(grep -o '"summary_done"\s*:\s*true' "$STATUS_FILE" 2>/dev/null || echo "")

# Output context summary
echo "===== CX 工作流 上下文 ====="
echo "功能: $CURRENT_FEATURE"
echo "进度: $COMPLETED_TASKS/$TOTAL_TASKS 任务完成"

if [[ -n "$IN_PROGRESS_TASK" && -z "$SUMMARY_DONE" ]]; then
  echo "⚠️  上次中断在 task-$IN_PROGRESS_TASK，建议继续执行"
elif [[ "$COMPLETED_TASKS" -eq "$TOTAL_TASKS" && -z "$SUMMARY_DONE" ]]; then
  echo "✅ 所有任务完成，建议运行 /cx-summary"
elif [[ -n "$SUMMARY_DONE" ]]; then
  echo "✅ 功能已完成并汇总"
fi
echo "============================="
