#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

cd "$REPO_ROOT"

echo "[check] config schema version"
rg '"enum": \["3.0"\]' references/config-schema.json

echo "[check] project status schema exists"
test -f references/project-status-schema.json

echo "[check] feature status schema exists"
test -f references/feature-status-schema.json

echo "[check] task template exists"
test -f references/templates/task.md

echo "[check] schema json parses"
jq empty references/config-schema.json references/project-status-schema.json references/feature-status-schema.json

echo "[check] feature status schema carries reason_type"
rg '"reason_type"' references/feature-status-schema.json

echo "[check] fixture json parses"
jq empty \
  tests/fixtures/minimal-project/.claude/cx/配置.json \
  tests/fixtures/minimal-project/.claude/cx/状态.json \
  tests/fixtures/minimal-project/.claude/cx/功能/示例功能/状态.json

echo "[check] cx-init per-project developer_id prompt"
rg '每个项目都单独确认 developer_id' skills/cx-init/SKILL.md

echo "[check] cx-init suggests creating GitHub remote"
rg '默认建议创建 GitHub 仓库并绑定' skills/cx-init/SKILL.md

echo "[check] cx-init uses project-level 配置.json wording"
rg '配置.json' skills/cx-init/SKILL.md

echo "[check] runtime helper and stop hook exist"
test -f hooks/cx-runtime.sh
test -f hooks/stop-check.sh

echo "[check] hook shell syntax"
bash -n hooks/cx-runtime.sh hooks/session-start.sh hooks/pre-compact.sh hooks/prompt-submit.sh hooks/post-edit.sh hooks/stop-check.sh

echo "[check] hooks use 3.0 Chinese runtime paths"
rg '配置.json|状态.json|功能/' hooks/cx-runtime.sh hooks/session-start.sh hooks/pre-compact.sh hooks/prompt-submit.sh hooks/post-edit.sh hooks/stop-check.sh

echo "[check] hooks no longer depend on old config or fixed refresh"
! rg 'config\\.json|features/' hooks/cx-runtime.sh hooks/session-start.sh hooks/pre-compact.sh hooks/prompt-submit.sh hooks/post-edit.sh hooks/stop-check.sh
! rg 'prompt_refresh_interval|\\.prompt-submit-counter' hooks/prompt-submit.sh

echo "[check] hooks manifest wires stop command"
jq empty hooks/hooks.json
rg 'stop-check.sh' hooks/hooks.json

echo "[check] session-start summarizes current feature"
SESSION_OUTPUT=$(PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/session-start.sh)
printf '%s\n' "$SESSION_OUTPUT" | rg '示例功能'
printf '%s\n' "$SESSION_OUTPUT" | rg '1/2'

echo "[check] pre-compact writes snapshot"
rm -f tests/fixtures/minimal-project/.claude/cx/context-snapshot.md
PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/pre-compact.sh
test -f tests/fixtures/minimal-project/.claude/cx/context-snapshot.md
rg 'sample-feature' tests/fixtures/minimal-project/.claude/cx/context-snapshot.md

echo "[check] prompt-submit stays quiet during normal execution"
PROMPT_OUTPUT=$(PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/prompt-submit.sh)
test -z "$PROMPT_OUTPUT"

echo "[check] stop hook reminds unfinished feature"
STOP_OUTPUT=$(PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/stop-check.sh)
printf '%s\n' "$STOP_OUTPUT" | rg '/cx-exec'

echo "[check] prompt-submit surfaces blocked reason only when needed"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
cp -R tests/fixtures/minimal-project/. "$TMP_DIR"
jq '.status = "blocked"
  | .blocked = {"reason_type":"needs_decision","message":"等待用户确认接口行为"}
  | .tasks = (.tasks | map(if .number == 2 then . + {"status":"blocked","reason_type":"needs_decision"} else . end))' \
  "$TMP_DIR/.claude/cx/功能/示例功能/状态.json" > "$TMP_DIR/feature-status.json"
mv "$TMP_DIR/feature-status.json" "$TMP_DIR/.claude/cx/功能/示例功能/状态.json"
BLOCKED_PROMPT=$(PROJECT_ROOT="$TMP_DIR" bash hooks/prompt-submit.sh)
printf '%s\n' "$BLOCKED_PROMPT" | rg 'needs_decision'
rm -f tests/fixtures/minimal-project/.claude/cx/context-snapshot.md

echo "[check] prd and plan follow pure cx 3.0 flow"
rg '自动判断是否需要 Design' skills/cx-prd/SKILL.md
rg '仅当 PRD 明显引入新技术时' skills/cx-plan/SKILL.md
! rg -F '{dev_id}-{feature}' skills/cx-prd/SKILL.md skills/cx-design/SKILL.md skills/cx-adr/SKILL.md skills/cx-plan/SKILL.md
rg '功能/' references/templates/prd.md references/templates/design.md references/templates/task.md
