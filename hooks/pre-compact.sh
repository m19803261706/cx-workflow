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
FEATURE_DIR=$(cx_feature_dir "$CURRENT_FEATURE")
if [[ -z "$STATUS_FILE" || ! -f "$STATUS_FILE" || -z "$FEATURE_DIR" ]]; then
  exit 0
fi

SNAPSHOT_FILE="$(cx_dir)/context-snapshot.md"
FEATURE_TITLE=$(cx_feature_title "$CURRENT_FEATURE")
FEATURE_STATUS=$(jq -r '.status // "drafting"' "$STATUS_FILE")
TOTAL_TASKS=$(jq -r '.total // 0' "$STATUS_FILE")
COMPLETED_TASKS=$(jq -r '.completed // 0' "$STATUS_FILE")
CURRENT_TASK=$(jq -r '.tasks[] | select(.status == "in_progress") | "task-\(.number) \(.title)"' "$STATUS_FILE" | head -n 1)
BLOCK_REASON=$(jq -r '.blocked.reason_type // empty' "$STATUS_FILE")
BLOCK_MESSAGE=$(jq -r '.blocked.message // empty' "$STATUS_FILE")
PRD_DOC=$(jq -r '.docs.prd // empty' "$STATUS_FILE")
DESIGN_DOC=$(jq -r '.docs.design // empty' "$STATUS_FILE")
SUMMARY_DOC=$(jq -r '.docs.summary // empty' "$STATUS_FILE")

cat > "$SNAPSHOT_FILE" << EOF
# CX 上下文快照

生成时间: $(date '+%Y-%m-%d %H:%M:%S')

- 当前功能: ${FEATURE_TITLE} (${CURRENT_FEATURE})
- 状态: ${FEATURE_STATUS}
- 进度: ${COMPLETED_TASKS}/${TOTAL_TASKS}
EOF

if [[ -n "$CURRENT_TASK" ]]; then
  cat >> "$SNAPSHOT_FILE" << EOF
- 当前任务: ${CURRENT_TASK}
EOF
fi

if [[ -n "$BLOCK_REASON" ]]; then
  cat >> "$SNAPSHOT_FILE" << EOF
- 阻塞原因: ${BLOCK_REASON}
- 阻塞说明: ${BLOCK_MESSAGE}
EOF
fi

cat >> "$SNAPSHOT_FILE" << EOF

## 文档入口

- 需求: \`${FEATURE_DIR}/${PRD_DOC}\`
EOF

if [[ -n "$DESIGN_DOC" ]]; then
  cat >> "$SNAPSHOT_FILE" << EOF
- 设计: \`${FEATURE_DIR}/${DESIGN_DOC}\`
EOF
fi

if [[ -n "$SUMMARY_DOC" ]]; then
  cat >> "$SNAPSHOT_FILE" << EOF
- 总结: \`${FEATURE_DIR}/${SUMMARY_DOC}\`
EOF
fi

cat >> "$SNAPSHOT_FILE" << EOF

## 恢复建议

- 查看进度: \`/cx-status\`
EOF

case "$FEATURE_STATUS" in
  completed)
    cat >> "$SNAPSHOT_FILE" << EOF
- 收尾汇总: \`/cx-summary\`
EOF
    ;;
  summarized)
    cat >> "$SNAPSHOT_FILE" << EOF
- 当前功能已汇总完成，可切换到下一个功能
EOF
    ;;
  *)
    cat >> "$SNAPSHOT_FILE" << EOF
- 继续执行: \`/cx-exec\`
EOF
    ;;
esac
