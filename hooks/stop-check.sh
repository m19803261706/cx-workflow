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

FEATURE_TITLE=$(cx_feature_title "$CURRENT_FEATURE")
if [[ -z "$FEATURE_TITLE" ]]; then
  exit 0
fi

FEATURE_STATUS=$(cx_feature_stage "$CURRENT_FEATURE")
CURRENT_TASK=$(cx_feature_current_task "$CURRENT_FEATURE")

if cx_feature_has_foreign_owner "$CURRENT_FEATURE"; then
  OWNER_RUNNER=$(cx_feature_owner_runner "$CURRENT_FEATURE")
  OWNER_SESSION=$(cx_feature_owner_session "$CURRENT_FEATURE")
  if cx_feature_lease_is_stale "$CURRENT_FEATURE"; then
    echo "cx(cc): 当前功能「${FEATURE_TITLE}」仍由 ${OWNER_RUNNER} 会话 ${OWNER_SESSION} 持有，但租约已过期。下次继续前请先走 handoff/claim。"
  else
    echo "cx(cc): 当前功能「${FEATURE_TITLE}」当前由 ${OWNER_RUNNER} 会话 ${OWNER_SESSION} 持有。CC 侧不要直接继续；需要接手时先走 handoff。"
  fi
  exit 0
fi

case "$FEATURE_STATUS" in
  blocked)
    BLOCK_REASON=$(cx_feature_block_reason "$CURRENT_FEATURE")
    BLOCK_MESSAGE=$(cx_feature_block_message "$CURRENT_FEATURE")
    echo "cx(cc): 当前功能「${FEATURE_TITLE}」已阻塞（${BLOCK_REASON:-unknown}）。${BLOCK_MESSAGE}"
    ;;
  completed)
    echo "cx(cc): 当前功能「${FEATURE_TITLE}」已完成但尚未汇总，退出前记得 /cx:cx-summary。"
    ;;
  summarized)
    exit 0
    ;;
  *)
    if [[ -n "$CURRENT_TASK" ]]; then
      echo "cx(cc): 当前停在「${FEATURE_TITLE}」的 ${CURRENT_TASK}，下次可用 /cx:cx-exec 继续。"
    else
      echo "cx(cc): 当前功能「${FEATURE_TITLE}」尚未完成，下次可用 /cx:cx-exec 继续。"
    fi
    ;;
esac
