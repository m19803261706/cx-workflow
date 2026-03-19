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
