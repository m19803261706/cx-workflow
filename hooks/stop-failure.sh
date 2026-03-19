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

CURRENT_FEATURE=$(cx_current_feature_slug)
FEATURE_TITLE=""
if [[ -n "$CURRENT_FEATURE" ]]; then
  FEATURE_TITLE=$(cx_feature_title "$CURRENT_FEATURE")
fi

cx_ensure_runtime_dir
OUTPUT_FILE="$(cx_runtime_dir)/最近失败.json"
FAILED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ERROR_TYPE=$(printf '%s' "$PAYLOAD" | jq -r '.error // "unknown"' 2>/dev/null || true)
FAILURE_MESSAGE=$(printf '%s' "$PAYLOAD" | jq -r '.message // .detail // empty' 2>/dev/null || true)

jq -n \
  --arg failed_at "$FAILED_AT" \
  --arg error "$ERROR_TYPE" \
  --arg message "$FAILURE_MESSAGE" \
  --arg current_feature "$CURRENT_FEATURE" \
  --arg feature_title "$FEATURE_TITLE" \
  --arg runner "$(cx_runner_name)" \
  '{
    failed_at: $failed_at,
    error: $error,
    message: $message,
    current_feature: $current_feature,
    feature_title: $feature_title,
    runner: $runner
  }' > "$OUTPUT_FILE"
