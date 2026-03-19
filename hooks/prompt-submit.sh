#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/cx-runtime.sh"

if ! cx_has_runtime || ! cx_require_jq; then
  exit 0
fi

CURRENT_FEATURE=$(cx_current_feature_slug)
if [[ -z "$CURRENT_FEATURE" ]]; then
  exit 0
fi

STATUS_FILE=$(cx_feature_status_file "$CURRENT_FEATURE")
if [[ -z "$STATUS_FILE" || ! -f "$STATUS_FILE" ]]; then
  exit 0
fi

FEATURE_TITLE=$(cx_feature_title "$CURRENT_FEATURE")
FEATURE_STATUS=$(jq -r '.status // "drafting"' "$STATUS_FILE")

case "$FEATURE_STATUS" in
  blocked)
    BLOCK_REASON=$(jq -r '.blocked.reason_type // empty' "$STATUS_FILE")
    BLOCK_MESSAGE=$(jq -r '.blocked.message // empty' "$STATUS_FILE")
    echo "cx: 当前功能「${FEATURE_TITLE}」已阻塞（${BLOCK_REASON:-unknown}）。${BLOCK_MESSAGE}"
    ;;
  completed)
    echo "cx: 当前功能「${FEATURE_TITLE}」已完成，如本轮是收尾可直接 /cx-summary。"
    ;;
esac
