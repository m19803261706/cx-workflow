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
FEATURE_STATUS=$(cx_feature_stage "$CURRENT_FEATURE")
TOTAL_TASKS=$(cx_feature_total_tasks "$CURRENT_FEATURE")
COMPLETED_TASKS=$(cx_feature_completed_tasks "$CURRENT_FEATURE")
CURRENT_TASK=$(cx_feature_current_task "$CURRENT_FEATURE")
BLOCK_REASON=$(cx_feature_block_reason "$CURRENT_FEATURE")
BLOCK_MESSAGE=$(cx_feature_block_message "$CURRENT_FEATURE")
WORKTREE_PATH=$(cx_feature_worktree_path "$CURRENT_FEATURE")
WORKTREE_BRANCH=$(cx_feature_worktree_branch "$CURRENT_FEATURE")
OWNER_RUNNER=$(cx_feature_owner_runner "$CURRENT_FEATURE")
OWNER_SESSION=$(cx_feature_owner_session "$CURRENT_FEATURE")
LATEST_HANDOFF=$(cx_feature_latest_handoff_record "$CURRENT_FEATURE")

if [[ -z "$FEATURE_TITLE" ]]; then
  exit 0
fi

cx_ensure_runtime_dir
SNAPSHOT_FILE="$(cx_runtime_dir)/context-snapshot.md"

cat > "$SNAPSHOT_FILE" << EOF
# CX 上下文快照

生成时间: $(date '+%Y-%m-%d %H:%M:%S')

- 当前运行器: cc
- 当前功能: ${FEATURE_TITLE} (${CURRENT_FEATURE})
- 状态: ${FEATURE_STATUS}
- 进度: ${COMPLETED_TASKS}/${TOTAL_TASKS}
EOF

if [[ -n "$CURRENT_TASK" ]]; then
  cat >> "$SNAPSHOT_FILE" << EOF
- 当前任务: ${CURRENT_TASK}
EOF
fi

if [[ -n "$OWNER_RUNNER" ]]; then
  cat >> "$SNAPSHOT_FILE" << EOF
- 当前 owner: ${OWNER_RUNNER}/${OWNER_SESSION}
EOF
fi

if [[ -n "$WORKTREE_PATH" ]]; then
  cat >> "$SNAPSHOT_FILE" << EOF
- 当前 worktree: ${WORKTREE_BRANCH} @ ${WORKTREE_PATH}
EOF
fi

if [[ -n "$BLOCK_REASON" ]]; then
  cat >> "$SNAPSHOT_FILE" << EOF
- 阻塞原因: ${BLOCK_REASON}
- 阻塞说明: ${BLOCK_MESSAGE}
EOF
fi

if [[ -n "$LATEST_HANDOFF" ]]; then
  cat >> "$SNAPSHOT_FILE" << EOF
- 最新 handoff: \`${LATEST_HANDOFF}\`
EOF
fi

cat >> "$SNAPSHOT_FILE" << EOF

## 恢复建议

- 查看进度: \`/cx:status\`
EOF

if cx_feature_has_foreign_owner "$CURRENT_FEATURE"; then
  cat >> "$SNAPSHOT_FILE" << EOF
- 当前 feature 由其他 runner 持有，先走 handoff，再继续 \`/cx:exec\`
EOF
else
  case "$FEATURE_STATUS" in
    completed)
      cat >> "$SNAPSHOT_FILE" << EOF
- 收尾汇总: \`/cx:summary\`
EOF
      ;;
    summarized)
      cat >> "$SNAPSHOT_FILE" << EOF
- 当前功能已汇总完成，可切换到下一个功能
EOF
      ;;
    *)
      cat >> "$SNAPSHOT_FILE" << EOF
- 继续执行: \`/cx:exec\`
EOF
      ;;
  esac
fi
