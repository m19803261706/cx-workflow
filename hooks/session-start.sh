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

FEATURE_TITLE=$(cx_feature_title "$CURRENT_FEATURE")
FEATURE_STATUS=$(cx_feature_stage "$CURRENT_FEATURE")
TOTAL_TASKS=$(cx_feature_total_tasks "$CURRENT_FEATURE")
COMPLETED_TASKS=$(cx_feature_completed_tasks "$CURRENT_FEATURE")
CURRENT_TASK=$(cx_feature_current_task "$CURRENT_FEATURE")

if [[ -z "$FEATURE_TITLE" ]]; then
  echo "cx(cc): 当前功能 ${CURRENT_FEATURE} 的状态记录缺失。"
  exit 0
fi

if cx_feature_has_foreign_owner "$CURRENT_FEATURE"; then
  OWNER_RUNNER=$(cx_feature_owner_runner "$CURRENT_FEATURE")
  OWNER_SESSION=$(cx_feature_owner_session "$CURRENT_FEATURE")
  WORKTREE_PATH=$(cx_feature_worktree_path "$CURRENT_FEATURE")
  if cx_feature_lease_is_stale "$CURRENT_FEATURE"; then
    echo "cx(cc): 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE}) 仍显示由 ${OWNER_RUNNER} 会话 ${OWNER_SESSION} 持有，但租约已过期。先走 handoff/claim，再继续执行。"
  else
    echo "cx(cc): 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE}) 当前由 ${OWNER_RUNNER} 会话 ${OWNER_SESSION} 持有。CC 侧不要直接继续；如需接手，请先走 handoff。${WORKTREE_PATH:+ 当前绑定 worktree: ${WORKTREE_PATH}}"
  fi
  exit 0
fi

case "$FEATURE_STATUS" in
  blocked)
    BLOCK_REASON=$(cx_feature_block_reason "$CURRENT_FEATURE")
    BLOCK_MESSAGE=$(cx_feature_block_message "$CURRENT_FEATURE")
    echo "cx(cc): 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE}) 已阻塞，原因：${BLOCK_REASON:-unknown}。${BLOCK_MESSAGE}"
    ;;
  completed)
    echo "cx(cc): 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE}) 已完成，建议运行 /cx:cx-summary 收尾。"
    ;;
  summarized)
    echo "cx(cc): 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE}) 已汇总完成。"
    ;;
  *)
    if [[ -n "$CURRENT_TASK" ]]; then
      echo "cx(cc): 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE})，进度 ${COMPLETED_TASKS}/${TOTAL_TASKS}，继续 ${CURRENT_TASK}。"
    else
      echo "cx(cc): 当前功能「${FEATURE_TITLE}」(${CURRENT_FEATURE})，进度 ${COMPLETED_TASKS}/${TOTAL_TASKS}。"
    fi
    ;;
esac
