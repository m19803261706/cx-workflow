#!/bin/bash

# Hook: PreCompact
# Purpose: Save context snapshot before compaction for recovery
# Allows Claude to recover essential context after token compaction

set -e

# Anchor to project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
CX_DIR="${PROJECT_ROOT}/.claude/cx"

# Check if cx config exists
if [[ ! -f "${CX_DIR}/config.json" ]]; then
  exit 0
fi

# Read current feature and task info from config
CURRENT_FEATURE=$(grep -o '"current_feature"\s*:\s*"[^"]*"' "${CX_DIR}/config.json" 2>/dev/null | cut -d'"' -f4 || echo "")

if [[ -z "$CURRENT_FEATURE" ]]; then
  exit 0
fi

# Read status.json
STATUS_FILE="${CX_DIR}/features/${CURRENT_FEATURE}/status.json"
if [[ ! -f "$STATUS_FILE" ]]; then
  exit 0
fi

# Parse current task number and progress
CURRENT_TASK=$(grep -o '"current_task"\s*:\s*[0-9]*' "$STATUS_FILE" 2>/dev/null | grep -o '[0-9]*' || echo "1")
TOTAL_TASKS=$(grep -o '"total"\s*:\s*[0-9]*' "$STATUS_FILE" 2>/dev/null | grep -o '[0-9]*' | tail -1 || echo "0")
COMPLETED_TASKS=$(grep -o '"completed"\s*:\s*[0-9]*' "$STATUS_FILE" 2>/dev/null | grep -o '[0-9]*' | tail -1 || echo "0")

# Read PRD file for contract summary (first few lines)
PRD_FILE="${CX_DIR}/features/${CURRENT_FEATURE}/prd.md"
CONTRACT_SUMMARY=""
if [[ -f "$PRD_FILE" ]]; then
  # Extract first 10 lines as contract summary
  CONTRACT_SUMMARY=$(head -20 "$PRD_FILE" 2>/dev/null | sed 's/^/  /')
fi

# Create context snapshot
SNAPSHOT_FILE="${CX_DIR}/context-snapshot.md"

cat > "$SNAPSHOT_FILE" << EOF
# Context Snapshot

**Generated**: $(date '+%Y-%m-%d %H:%M:%S')

## Current State

- **Feature**: $CURRENT_FEATURE
- **Current Task**: $CURRENT_TASK
- **Progress**: $COMPLETED_TASKS/$TOTAL_TASKS completed

## Task Summary

Refer to: \`.claude/cx/features/$CURRENT_FEATURE/tasks.json\`

## Design Contracts

\`\`\`
$CONTRACT_SUMMARY
\`\`\`

For full contract details, see: \`.claude/cx/features/$CURRENT_FEATURE/design.md\`

## Recovery Notes

If context has been compacted, refer to this snapshot to understand the current state before resuming work.

- Use \`/cx-status\` to view current progress
- Use \`/cx-exec\` to continue task execution
- Use \`/cx-summary\` if all tasks are complete
EOF
