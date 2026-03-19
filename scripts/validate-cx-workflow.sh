#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

cd "$REPO_ROOT"

validate_core_project_cross_references() {
  local registry_path="$1"

  jq -e '
    all(.features | to_entries[];
      .key == .value.slug)
  ' "$registry_path" >/dev/null || return 1

  jq -e '
    all(.active_sessions | to_entries[];
      .key == .value.session_id)
  ' "$registry_path" >/dev/null || return 1

  jq -e '
    .current_feature as $current_feature
    | ($current_feature == null) or (.features | has($current_feature))
  ' "$registry_path" >/dev/null || return 1

  jq -e '
    .active_sessions as $sessions
    | all(.features[]?;
        (.lease_session_id as $lease_session_id
          | ($lease_session_id == null) or ($sessions | has($lease_session_id))))
  ' "$registry_path" >/dev/null || return 1
}

echo "[check] config schema version"
jq -e '.properties.version.enum == ["3.0"]' references/config-schema.json >/dev/null

echo "[check] project status schema exists"
test -f references/project-status-schema.json

echo "[check] feature status schema exists"
test -f references/feature-status-schema.json

echo "[check] core control plane docs and schemas exist"
test -f references/core-schema-overview.md
test -f references/core-project-schema.json
test -f references/core-feature-schema.json
test -f references/core-session-schema.json
test -f references/core-handoff-schema.json

echo "[check] task template exists"
test -f references/templates/task.md

echo "[check] schema json parses"
jq empty references/config-schema.json references/project-status-schema.json references/feature-status-schema.json

echo "[check] core schema json parses"
jq empty \
  references/core-project-schema.json \
  references/core-feature-schema.json \
  references/core-session-schema.json \
  references/core-handoff-schema.json

echo "[check] feature status schema carries reason_type"
jq -e '.properties.blocked.required | index("reason_type")' references/feature-status-schema.json >/dev/null

echo "[check] core project schema carries control plane pointers"
jq -e '.required | index("version")' references/core-project-schema.json >/dev/null
jq -e '.required | index("features")' references/core-project-schema.json >/dev/null
jq -e '.required | index("active_sessions")' references/core-project-schema.json >/dev/null
jq -e '.required | index("runtime_roots")' references/core-project-schema.json >/dev/null
jq -e '.properties.current_feature' references/core-project-schema.json >/dev/null
jq -e '.definitions.feature_slug.pattern == "^[a-z0-9_-]+$"' references/core-project-schema.json >/dev/null
jq -e '.definitions.session_identifier.pattern == "^[a-z0-9][a-z0-9._:-]*$"' references/core-project-schema.json >/dev/null
jq -e '.properties.features.propertyNames."$ref" == "#/definitions/feature_slug"' references/core-project-schema.json >/dev/null
jq -e '.properties.active_sessions.propertyNames."$ref" == "#/definitions/session_identifier"' references/core-project-schema.json >/dev/null
jq -e '.properties.current_feature.anyOf[0]."$ref" == "#/definitions/feature_slug" and .properties.current_feature.anyOf[1].type == "null"' references/core-project-schema.json >/dev/null
jq -e '.properties.features.additionalProperties.properties.lease_session_id.anyOf[0]."$ref" == "#/definitions/session_identifier" and .properties.features.additionalProperties.properties.lease_session_id.anyOf[1].type == "null"' references/core-project-schema.json >/dev/null
jq -e '.properties.active_sessions.additionalProperties.properties.claimed_tasks.items."$ref" == "#/definitions/task_identifier"' references/core-project-schema.json >/dev/null

echo "[check] core claimed_tasks identifiers are traceable"
jq -e '.definitions.task_identifier.oneOf[0].type == "integer" and .definitions.task_identifier.oneOf[0].minimum == 1 and .definitions.task_identifier.oneOf[1].type == "string" and .definitions.task_identifier.oneOf[1].pattern == "^(task-[1-9][0-9]*|[a-z][a-z0-9._-]*)$"' references/core-project-schema.json >/dev/null
jq -e '.definitions.task_identifier.oneOf[0].type == "integer" and .definitions.task_identifier.oneOf[0].minimum == 1 and .definitions.task_identifier.oneOf[1].type == "string" and .definitions.task_identifier.oneOf[1].pattern == "^(task-[1-9][0-9]*|[a-z][a-z0-9._-]*)$"' references/core-feature-schema.json >/dev/null
jq -e '.definitions.task_identifier.oneOf[0].type == "integer" and .definitions.task_identifier.oneOf[0].minimum == 1 and .definitions.task_identifier.oneOf[1].type == "string" and .definitions.task_identifier.oneOf[1].pattern == "^(task-[1-9][0-9]*|[a-z][a-z0-9._-]*)$"' references/core-session-schema.json >/dev/null
jq -e '.definitions.task_identifier.oneOf[0].type == "integer" and .definitions.task_identifier.oneOf[0].minimum == 1 and .definitions.task_identifier.oneOf[1].type == "string" and .definitions.task_identifier.oneOf[1].pattern == "^(task-[1-9][0-9]*|[a-z][a-z0-9._-]*)$"' references/core-handoff-schema.json >/dev/null

echo "[check] core feature schema carries lease and handoff metadata"
jq -e '.required | index("slug")' references/core-feature-schema.json >/dev/null
jq -e '.required | index("title")' references/core-feature-schema.json >/dev/null
jq -e '.required | index("lifecycle")' references/core-feature-schema.json >/dev/null
jq -e '.required | index("planning_owner")' references/core-feature-schema.json >/dev/null
jq -e '.required | index("execution_owner")' references/core-feature-schema.json >/dev/null
jq -e '.required | index("worktree")' references/core-feature-schema.json >/dev/null
jq -e '.required | index("lease")' references/core-feature-schema.json >/dev/null
jq -e '.required | index("docs")' references/core-feature-schema.json >/dev/null
jq -e '.required | index("tasks")' references/core-feature-schema.json >/dev/null
jq -e '.required | index("handoffs")' references/core-feature-schema.json >/dev/null
jq -e '.properties.lease.required | index("runner")' references/core-feature-schema.json >/dev/null
jq -e '.properties.lease.required | index("session_id")' references/core-feature-schema.json >/dev/null
jq -e '.properties.lease.required | index("branch")' references/core-feature-schema.json >/dev/null
jq -e '.properties.lease.required | index("worktree_path")' references/core-feature-schema.json >/dev/null
jq -e '.properties.lease.required | index("claimed_feature")' references/core-feature-schema.json >/dev/null
jq -e '.properties.lease.required | index("claimed_tasks")' references/core-feature-schema.json >/dev/null
jq -e '.properties.lease.required | index("claimed_at")' references/core-feature-schema.json >/dev/null
jq -e '.properties.lease.required | index("expires_at")' references/core-feature-schema.json >/dev/null
jq -e '.properties.lease.properties.claimed_tasks.items."$ref" == "#/definitions/task_identifier"' references/core-feature-schema.json >/dev/null

echo "[check] core session schema carries runner lease ownership"
jq -e '.required | index("runner")' references/core-session-schema.json >/dev/null
jq -e '.required | index("session_id")' references/core-session-schema.json >/dev/null
jq -e '.required | index("branch")' references/core-session-schema.json >/dev/null
jq -e '.required | index("worktree_path")' references/core-session-schema.json >/dev/null
jq -e '.required | index("started_at")' references/core-session-schema.json >/dev/null
jq -e '.required | index("last_heartbeat")' references/core-session-schema.json >/dev/null
jq -e '.required | index("claimed_feature")' references/core-session-schema.json >/dev/null
jq -e '.required | index("claimed_tasks")' references/core-session-schema.json >/dev/null
jq -e '.properties.claimed_tasks.items."$ref" == "#/definitions/task_identifier"' references/core-session-schema.json >/dev/null

echo "[check] core handoff schema carries transfer lifecycle"
jq -e '.required | index("runner")' references/core-handoff-schema.json >/dev/null
jq -e '.required | index("session_id")' references/core-handoff-schema.json >/dev/null
jq -e '.required | index("branch")' references/core-handoff-schema.json >/dev/null
jq -e '.required | index("worktree_path")' references/core-handoff-schema.json >/dev/null
jq -e '.required | index("claimed_feature")' references/core-handoff-schema.json >/dev/null
jq -e '.required | index("claimed_tasks")' references/core-handoff-schema.json >/dev/null
jq -e '.required | index("handoff_reason")' references/core-handoff-schema.json >/dev/null
jq -e '.required | index("accepted_at")' references/core-handoff-schema.json >/dev/null
jq -e '.properties.claimed_tasks.items."$ref" == "#/definitions/task_identifier"' references/core-handoff-schema.json >/dev/null

echo "[check] core-dual-runner fixture parses"
jq empty \
  tests/fixtures/core-dual-runner/.claude/cx/core/projects/core-dual-runner.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/features/dual-runner-claim-a.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/features/dual-runner-claim-b.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/features/dual-runner-task-lock.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/features/dual-runner-handoff.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/sessions/codex-claim-001.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/sessions/codex-task-owner.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/sessions/cc-source-001.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/sessions/codex-target-001.json

echo "[check] core claim script exists"
test -f scripts/cx-core-claim.sh
test -f scripts/cx-core-handoff.sh
test -f references/templates/core-feature.md

echo "[check] core claim keeps different features isolated"
CORE_SCENARIO_DIR=$(mktemp -d)
cp -R tests/fixtures/core-dual-runner/. "$CORE_SCENARIO_DIR"
CX_CORE_NOW=2026-03-20T10:00:00Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-claim.sh \
  --runner cc \
  --session-id cc-claim-002 \
  --branch cc/dual-runner-claim-b \
  --worktree-path /worktrees/dual-runner-claim-b \
  --feature dual-runner-claim-b \
  --tasks 1
jq -e '.features["dual-runner-claim-b"].lease_session_id == "cc-claim-002"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/projects/core-dual-runner.json" >/dev/null
jq -e '.active_sessions["cc-claim-002"].claimed_feature == "dual-runner-claim-b"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/projects/core-dual-runner.json" >/dev/null
jq -e '.tasks[0].owner_session_id == "cc-claim-002"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/features/dual-runner-claim-b.json" >/dev/null
rm -rf "$CORE_SCENARIO_DIR"

echo "[check] core claim rejects same-feature conflicts"
CORE_SCENARIO_DIR=$(mktemp -d)
cp -R tests/fixtures/core-dual-runner/. "$CORE_SCENARIO_DIR"
if CX_CORE_NOW=2026-03-20T10:05:00Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-claim.sh \
  --runner cc \
  --session-id cc-claim-002 \
  --branch cc/dual-runner-claim-a \
  --worktree-path /worktrees/dual-runner-claim-a \
  --feature dual-runner-claim-a \
  --tasks 2; then
  echo "same-feature claim conflict should fail" >&2
  rm -rf "$CORE_SCENARIO_DIR"
  exit 1
fi
jq -e '.features["dual-runner-claim-a"].lease_session_id == "codex-claim-001"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/projects/core-dual-runner.json" >/dev/null
rm -rf "$CORE_SCENARIO_DIR"

echo "[check] core claim rejects task-level conflicts"
CORE_SCENARIO_DIR=$(mktemp -d)
cp -R tests/fixtures/core-dual-runner/. "$CORE_SCENARIO_DIR"
if CX_CORE_NOW=2026-03-20T10:06:00Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-claim.sh \
  --runner cc \
  --session-id cc-task-conflict-001 \
  --branch cc/dual-runner-task-lock \
  --worktree-path /worktrees/dual-runner-task-lock \
  --feature dual-runner-task-lock \
  --tasks 1; then
  echo "task-level claim conflict should fail" >&2
  rm -rf "$CORE_SCENARIO_DIR"
  exit 1
fi
! test -f "$CORE_SCENARIO_DIR/.claude/cx/core/sessions/cc-task-conflict-001.json"
rm -rf "$CORE_SCENARIO_DIR"

echo "[check] core handoff transfers cc to codex"
CORE_SCENARIO_DIR=$(mktemp -d)
cp -R tests/fixtures/core-dual-runner/. "$CORE_SCENARIO_DIR"
CX_CORE_NOW=2026-03-20T10:07:00Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-handoff.sh \
  --source-runner cc \
  --source-session-id cc-source-001 \
  --target-runner codex \
  --target-session-id codex-target-001 \
  --feature dual-runner-handoff \
  --reason "cc side finished and codex will continue"
jq -e '.features["dual-runner-handoff"].lease_session_id == "codex-target-001"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/projects/core-dual-runner.json" >/dev/null
jq -e '.execution_owner.session_id == "codex-target-001"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/features/dual-runner-handoff.json" >/dev/null
jq -e 'all(.tasks[]; .owner_session_id == "codex-target-001")' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/features/dual-runner-handoff.json" >/dev/null
jq -e '.active_sessions["cc-source-001"].claimed_feature == null and .active_sessions["codex-target-001"].claimed_feature == "dual-runner-handoff"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/projects/core-dual-runner.json" >/dev/null
jq -e '.active_sessions["codex-target-001"].claimed_tasks == [1,2]' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/projects/core-dual-runner.json" >/dev/null
HandoffRecordPath=$(jq -r '.handoffs[-1].record_path' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/features/dual-runner-handoff.json")
test -f "$CORE_SCENARIO_DIR/$HandoffRecordPath"
jq empty "$CORE_SCENARIO_DIR/$HandoffRecordPath"
rm -rf "$CORE_SCENARIO_DIR"

echo "[check] core project cross references stay non-dangling"
CORE_TMP_DIR=$(mktemp -d)
jq -n '{
  "version": "1.0",
  "current_feature": "cx-core-dual-runner",
  "features": {
    "cx-core-dual-runner": {
      "slug": "cx-core-dual-runner",
      "title": "Shared cx core control plane",
      "path": ".claude/cx/core/features/cx-core-dual-runner.json",
      "lifecycle": "executing",
      "worktree_path": "/worktrees/codex-cx-core-dual-runner",
      "lease_session_id": "codex-20260320-001",
      "last_updated": "2026-03-20T09:00:00Z"
    }
  },
  "active_sessions": {
    "codex-20260320-001": {
      "runner": "codex",
      "session_id": "codex-20260320-001",
      "branch": "codex/cx-core-dual-runner",
      "worktree_path": "/worktrees/codex-cx-core-dual-runner",
      "started_at": "2026-03-20T08:50:00Z",
      "last_heartbeat": "2026-03-20T09:00:00Z",
      "claimed_feature": "cx-core-dual-runner",
      "claimed_tasks": [1]
    }
  },
  "runtime_roots": {
    "projects": ".claude/cx/core/projects",
    "features": ".claude/cx/core/features",
    "sessions": ".claude/cx/core/sessions",
    "handoffs": ".claude/cx/core/handoffs",
    "worktrees": ".claude/cx/core/worktrees",
    "artifacts": {
      "cx": ".claude/cx/runtime/cx",
      "cc": ".claude/cx/runtime/cc",
      "codex": ".claude/cx/runtime/codex"
    }
  }
}' > "$CORE_TMP_DIR/core-project.json"
validate_core_project_cross_references "$CORE_TMP_DIR/core-project.json"

jq '.current_feature = "missing-feature"' \
  "$CORE_TMP_DIR/core-project.json" > "$CORE_TMP_DIR/core-project-missing-feature.json"
if validate_core_project_cross_references "$CORE_TMP_DIR/core-project-missing-feature.json"; then
  echo "current_feature cross-reference check should reject missing feature keys" >&2
  rm -rf "$CORE_TMP_DIR"
  exit 1
fi

jq '.features["cx-core-dual-runner"].lease_session_id = "missing-session"' \
  "$CORE_TMP_DIR/core-project.json" > "$CORE_TMP_DIR/core-project-missing-lease-session.json"
if validate_core_project_cross_references "$CORE_TMP_DIR/core-project-missing-lease-session.json"; then
  echo "lease_session_id cross-reference check should reject missing active sessions" >&2
  rm -rf "$CORE_TMP_DIR"
  exit 1
fi

jq '(.features["wrong-feature-key"] = .features["cx-core-dual-runner"])
  | del(.features["cx-core-dual-runner"])
  | .features["wrong-feature-key"].slug = "cx-core-dual-runner"' \
  "$CORE_TMP_DIR/core-project.json" > "$CORE_TMP_DIR/core-project-feature-key-drift.json"
if validate_core_project_cross_references "$CORE_TMP_DIR/core-project-feature-key-drift.json"; then
  echo "feature registry key/value identity drift should be rejected" >&2
  rm -rf "$CORE_TMP_DIR"
  exit 1
fi

jq '(.active_sessions["wrong-session-key"] = .active_sessions["codex-20260320-001"])
  | del(.active_sessions["codex-20260320-001"])
  | .active_sessions["wrong-session-key"].session_id = "codex-20260320-001"' \
  "$CORE_TMP_DIR/core-project.json" > "$CORE_TMP_DIR/core-project-session-key-drift.json"
if validate_core_project_cross_references "$CORE_TMP_DIR/core-project-session-key-drift.json"; then
  echo "session registry key/value identity drift should be rejected" >&2
  rm -rf "$CORE_TMP_DIR"
  exit 1
fi
rm -rf "$CORE_TMP_DIR"

if [[ -d tests/fixtures/minimal-project ]]; then
  echo "[check] fixture json parses"
  jq empty \
    tests/fixtures/minimal-project/.claude/cx/配置.json \
    tests/fixtures/minimal-project/.claude/cx/状态.json \
    tests/fixtures/minimal-project/.claude/cx/功能/示例功能/状态.json

  echo "[check] cx-init per-project developer_id prompt"
  rg '每个项目都单独确认 developer_id' skills/init/SKILL.md

  echo "[check] cx-init suggests creating GitHub remote"
  rg '默认建议创建 GitHub 仓库并绑定' skills/init/SKILL.md

  echo "[check] cx-init uses project-level 配置.json wording"
  rg '配置.json' skills/init/SKILL.md

  echo "[check] cx-init no longer writes project settings hooks"
  ! rg 'settings\\.json|plugin-dir' scripts/cx-init-setup.sh

  echo "[check] runtime helper and hook scripts exist"
  test -f hooks/cx-runtime.sh
  test -f hooks/stop-check.sh
  test -f hooks/stop-failure.sh
  test -f hooks/config-change.sh

  echo "[check] hook shell syntax"
  bash -n hooks/cx-runtime.sh hooks/session-start.sh hooks/pre-compact.sh hooks/prompt-submit.sh hooks/post-edit.sh hooks/stop-check.sh hooks/stop-failure.sh hooks/config-change.sh

  echo "[check] hooks use 3.1 Chinese runtime paths"
  rg '配置.json|状态.json|功能/' hooks/cx-runtime.sh hooks/session-start.sh hooks/pre-compact.sh hooks/prompt-submit.sh hooks/post-edit.sh hooks/stop-check.sh

  echo "[check] hooks no longer depend on old config or fixed refresh"
  ! rg 'config\\.json|features/' hooks/cx-runtime.sh hooks/session-start.sh hooks/pre-compact.sh hooks/prompt-submit.sh hooks/post-edit.sh hooks/stop-check.sh
  ! rg 'prompt_refresh_interval|\\.prompt-submit-counter' hooks/prompt-submit.sh

  echo "[check] hooks manifest wires 2026 official events"
  jq empty hooks/hooks.json
  rg 'stop-check.sh' hooks/hooks.json
  rg 'stop-failure.sh' hooks/hooks.json
  rg 'config-change.sh' hooks/hooks.json

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
  printf '%s\n' "$STOP_OUTPUT" | rg '/cx:exec'

  echo "[check] stop-failure writes failure snapshot"
  rm -f tests/fixtures/minimal-project/.claude/cx/最近失败.json
  printf '%s' '{"error":"rate_limit","message":"Too many requests"}' | PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/stop-failure.sh
  test -f tests/fixtures/minimal-project/.claude/cx/最近失败.json
  rg '"error": "rate_limit"' tests/fixtures/minimal-project/.claude/cx/最近失败.json

  echo "[check] config-change writes config snapshot"
  rm -f tests/fixtures/minimal-project/.claude/cx/最近配置变更.json
  printf '%s' '{"source":"project_settings","file_path":".claude/settings.json"}' | PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/config-change.sh
  test -f tests/fixtures/minimal-project/.claude/cx/最近配置变更.json
  rg '"source": "project_settings"' tests/fixtures/minimal-project/.claude/cx/最近配置变更.json

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
else
  echo "[skip] minimal-project fixture absent; legacy hook smoke checks skipped"
fi

echo "[check] prd and plan follow pure cx 3.1 flow"
rg '自动判断是否需要 Design' skills/prd/SKILL.md
rg '仅当 PRD 明显引入新技术时' skills/plan/SKILL.md
! rg -F '{dev_id}-{feature}' skills/prd/SKILL.md skills/design/SKILL.md skills/adr/SKILL.md skills/plan/SKILL.md
rg '功能/' references/templates/prd.md references/templates/design.md references/templates/task.md

echo "[check] execution chain follows pure cx 3.1 semantics"
rg '/cx:exec --all' skills/exec/SKILL.md
rg -F '3+ 专业代理' skills/exec/SKILL.md
rg -F '[cx:<feature-slug>] [task:<n>]' skills/exec/SKILL.md
rg 'reason_type' skills/status/SKILL.md skills/exec/SKILL.md
rg 'GitHub 为同步镜像' skills/summary/SKILL.md skills/help/SKILL.md
rg '配置.json' skills/config/SKILL.md
! rg 'background_agents|prompt_refresh_interval' skills/config/SKILL.md
rg 'disable-model-invocation: true' skills/init/SKILL.md skills/prd/SKILL.md skills/plan/SKILL.md skills/design/SKILL.md skills/adr/SKILL.md skills/exec/SKILL.md skills/fix/SKILL.md skills/summary/SKILL.md skills/config/SKILL.md skills/scope/SKILL.md
rg '修复/' references/templates/fix.md
rg '总结.md' references/templates/summary.md

echo "[check] public docs and metadata present pure cx 3.1"
rg '"name": "cx"' .claude-plugin/plugin.json .claude-plugin/marketplace.json
rg '"version": "3.1.0"' .claude-plugin/plugin.json .claude-plugin/marketplace.json
rg '只保留 `cx`' README.md references/workflow-guide.md
! rg -F '/tc' README.md references/workflow-guide.md
rg '/cx:init' README.md references/workflow-guide.md skills/help/SKILL.md
rg '纯 cx 3.1|/cx:\*' README.md references/workflow-guide.md CHANGELOG.md
