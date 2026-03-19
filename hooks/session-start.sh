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
  echo "cx: 当前没有活跃功能。"
  exit 0
fi

STATUS_FILE=$(cx_feature_status_file "$CURRENT_FEATURE")
if [[ -z "$STATUS_FILE" || ! -f "$STATUS_FILE" ]]; then
  echo "cx: 当前功能 ${CURRENT_FEATURE} 的状态记录缺失。"
  exit 0
fi

FEATURE_TITLE=$(cx_feature_title "$CURRENT_FEATURE")
FEATURE_STATUS=$(jq -r '.status // "drafting"' "$STATUS_FILE")
TOTAL_TASKS=$(jq -r '.total // 0' "$STATUS_FILE")
COMPLETED_TASKS=$(jq -r '.completed // 0' "$STATUS_FILE")
CURRENT_TASK=$(jq -r '.tasks[] | select(.status == "in_progress") | "task-\(.number) \(.title)"' "$STATUS_FILE" | head -n 1)

case "$FEATURE_STATUS" in
  blocked)
    BLOCK_REASON=$(jq -r '.blocked.reason_type // empty' "$STATUS_FILE")
    BLOCK_MESSAGE=$(jq -r '.blocked.message // empty' "$STATUS_FILE")
    echo "cx: 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE}) 已阻塞，原因：${BLOCK_REASON:-unknown}。${BLOCK_MESSAGE}"
    ;;
  completed)
    echo "cx: 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE}) 已完成，建议运行 /cx:summary 收尾。"
    ;;
  summarized)
    echo "cx: 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE}) 已汇总完成。"
    ;;
  *)
    if [[ -n "$CURRENT_TASK" ]]; then
      echo "cx: 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE})，进度 ${COMPLETED_TASKS}/${TOTAL_TASKS}，继续 ${CURRENT_TASK}。"
    else
      echo "cx: 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE})，进度 ${COMPLETED_TASKS}/${TOTAL_TASKS}。"
    fi
    ;;
esac
