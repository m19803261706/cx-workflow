#!/bin/bash

# Hook: PermissionRequest
# Purpose: Auto-approve safe commands without requiring user confirmation
# Usage: permission-auto-approve.sh "git add file.js"
# Output: "approve" or "deny" to stdout

set -e

# Get command from argument
COMMAND="$1"

# Check if command is empty
if [[ -z "$COMMAND" ]]; then
  echo "deny"
  exit 0
fi

# Define safe command patterns (whitelist)
declare -a SAFE_PATTERNS=(
  "git add"
  "git commit"
  "git push"
  "git checkout"
  "git branch"
  "git status"
  "git log"
  "git diff"
  "gh issue"
  "gh pr"
  "gh project"
  "npm test"
  "npm run lint"
  "npm run format"
  "pytest"
  "python -m pytest"
  "cargo test"
  "go test"
)

# Check if command matches any safe pattern
for pattern in "${SAFE_PATTERNS[@]}"; do
  # Use word boundary matching to ensure pattern matches the start of command
  if [[ "$COMMAND" =~ ^${pattern}[[:space:]] || "$COMMAND" == "${pattern}" ]]; then
    echo "approve"
    exit 0
  fi
done

# If no safe pattern matched, deny
echo "deny"
exit 0
