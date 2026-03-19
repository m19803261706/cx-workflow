#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/cx-runtime.sh"

if ! cx_has_runtime || ! cx_require_jq; then
  exit 0
fi

PAYLOAD=""
if [[ ! -t 0 ]]; then
  PAYLOAD=$(cat)
fi

if [[ -z "$PAYLOAD" ]]; then
  exit 0
fi

cx_ensure_runtime_dir
OUTPUT_FILE="$(cx_runtime_dir)/最近配置变更.json"
CHANGED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SOURCE=$(printf '%s' "$PAYLOAD" | jq -r '.source // empty' 2>/dev/null || true)
FILE_PATH=$(printf '%s' "$PAYLOAD" | jq -r '.file_path // empty' 2>/dev/null || true)

jq -n \
  --arg changed_at "$CHANGED_AT" \
  --arg source "$SOURCE" \
  --arg file_path "$FILE_PATH" \
  --arg runner "$(cx_runner_name)" \
  '{
    changed_at: $changed_at,
    source: $source,
    file_path: $file_path,
    runner: $runner
  }' > "$OUTPUT_FILE"
