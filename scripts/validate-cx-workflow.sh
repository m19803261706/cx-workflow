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

echo "[check] shared workflow core docs and schema exist"
test -f core/README.md
test -f core/workflow/README.md
test -f core/workflow/protocols/prd.md
test -f core/workflow/protocols/design.md
test -f core/workflow/protocols/plan.md
test -f core/workflow/protocols/exec.md
test -f core/workflow/protocols/fix.md
test -f core/workflow/protocols/status.md
test -f core/workflow/protocols/summary.md
test -f references/workflow-state-schema.json

echo "[check] dashboard architecture docs and schema exist"
test -f docs/dashboard-architecture.md
test -f references/dashboard-registry-schema.json
test -f references/dashboard-runtime-schema.json
test -f apps/dashboard-service/package.json
test -f apps/dashboard-service/src/server.ts
test -f apps/dashboard-service/src/registry.ts
test -f apps/dashboard-service/src/projects.ts
test -f apps/dashboard-service/src/runtime.ts
test -f apps/dashboard-service/src/routes/projects.ts
test -f apps/dashboard-service/src/routes/projects.test.ts
test -f apps/dashboard-service/src/runtime.test.ts
test -f apps/dashboard-web/package.json
test -f apps/dashboard-web/src/main.tsx
test -f apps/dashboard-web/src/App.tsx
test -f apps/dashboard-web/src/pages/projects.tsx
test -f apps/dashboard-web/src/pages/project-detail.tsx
test -f apps/dashboard-web/src/components/project-card.tsx
test -f apps/dashboard-web/src/components/project-card.test.tsx
test -f apps/dashboard-web/src/components/feature-summary.tsx
test -f apps/dashboard-web/src/components/handoff-banner.tsx
test -f apps/dashboard-web/src/pages/project-detail.test.tsx
test -f docs/dashboard-smoke-test.md
test -f tests/fixtures/dashboard-projects/summary-expectations.json
test -f tests/fixtures/dashboard-projects/project-detail.json
test -f scripts/cx-dashboard-bridge.sh
test -f scripts/cx-dashboard-ensure.sh
test -f scripts/cx-dashboard-open.sh

echo "[check] task template exists"
test -f references/templates/task.md

echo "[check] schema json parses"
jq empty \
  references/config-schema.json \
  references/project-status-schema.json \
  references/feature-status-schema.json \
  references/workflow-state-schema.json \
  references/dashboard-registry-schema.json \
  references/dashboard-runtime-schema.json

echo "[check] core schema json parses"
jq empty \
  references/core-project-schema.json \
  references/core-feature-schema.json \
  references/core-session-schema.json \
  references/core-handoff-schema.json

echo "[check] dashboard registry schema carries prompt and registration metadata"
jq -e '.required | index("prompt_state")' references/dashboard-registry-schema.json >/dev/null
jq -e '.required | index("auto_register")' references/dashboard-registry-schema.json >/dev/null
jq -e '.required | index("projects")' references/dashboard-registry-schema.json >/dev/null
jq -e '.definitions.registration_source.enum == ["manual","auto_register","auto_scan"]' references/dashboard-registry-schema.json >/dev/null
jq -e '.definitions.prompt_state.enum == ["unknown","accepted","declined"]' references/dashboard-registry-schema.json >/dev/null
jq -e '.definitions.owner_runner.enum == ["cc","codex","none"]' references/dashboard-registry-schema.json >/dev/null

echo "[check] dashboard runtime schema carries service runtime metadata"
jq -e '.required | index("service_status")' references/dashboard-runtime-schema.json >/dev/null
jq -e '.required | index("backend_port")' references/dashboard-runtime-schema.json >/dev/null
jq -e '.required | index("frontend_port")' references/dashboard-runtime-schema.json >/dev/null
jq -e '.required | index("frontend_url")' references/dashboard-runtime-schema.json >/dev/null
jq -e '.definitions.service_status.enum == ["stopped","running","degraded"]' references/dashboard-runtime-schema.json >/dev/null

echo "[check] feature status schema carries reason_type"
jq -e '.properties.blocked.required | index("reason_type")' references/feature-status-schema.json >/dev/null
jq -e '.properties.workflow.required | index("current_phase")' references/feature-status-schema.json >/dev/null
jq -e '.properties.workflow.required | index("next_route")' references/feature-status-schema.json >/dev/null

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
jq -e '.properties.features.additionalProperties.properties.workflow_phase' references/core-project-schema.json >/dev/null
jq -e '.properties.features.additionalProperties.properties.next_route' references/core-project-schema.json >/dev/null

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
jq -e '.properties.workflow.required | index("current_phase")' references/core-feature-schema.json >/dev/null
jq -e '.properties.workflow.required | index("completion_status")' references/core-feature-schema.json >/dev/null

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
  tests/fixtures/core-dual-runner/.claude/cx/core/worktrees/dual-runner-claim-a.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/worktrees/dual-runner-claim-b.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/worktrees/dual-runner-task-lock.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/worktrees/dual-runner-handoff.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/sessions/codex-claim-001.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/sessions/codex-task-owner.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/sessions/cc-source-001.json \
  tests/fixtures/core-dual-runner/.claude/cx/core/sessions/codex-target-001.json

echo "[check] core claim script exists"
test -f scripts/cx-core-claim.sh
test -f scripts/cx-core-handoff.sh
test -f scripts/cx-core-worktree.sh
test -f scripts/cx-workflow-prd.sh
test -f scripts/cx-workflow-plan.sh
test -f scripts/cx-workflow-exec.sh
test -f scripts/cx-workflow-exec-dispatch.sh
test -f scripts/cx-workflow-design.sh
test -f scripts/cx-workflow-status.sh
test -f scripts/cx-workflow-summary.sh
test -f scripts/cx-workflow-fix.sh
test -f references/templates/core-feature.md

echo "[check] workflow runner shell syntax"
bash -n \
  scripts/cx-workflow-prd.sh \
  scripts/cx-workflow-plan.sh \
  scripts/cx-workflow-exec.sh \
  scripts/cx-workflow-exec-dispatch.sh \
  scripts/cx-workflow-design.sh \
  scripts/cx-workflow-status.sh \
  scripts/cx-workflow-summary.sh \
  scripts/cx-workflow-fix.sh \
  scripts/cx-dashboard-bridge.sh \
  scripts/cx-dashboard-ensure.sh \
  scripts/cx-dashboard-open.sh

echo "[check] dashboard service tests"
(cd apps/dashboard-service && npm test)

echo "[check] dashboard service typecheck"
(cd apps/dashboard-service && npm run typecheck)

echo "[check] dashboard web tests"
(cd apps/dashboard-web && npm test)

echo "[check] dashboard web typecheck"
(cd apps/dashboard-web && npm run typecheck)

echo "[check] dashboard web build"
(cd apps/dashboard-web && npm run build)

echo "[check] dashboard bridge honors first-use prompt and later auto-register"
BRIDGE_HOME=$(mktemp -d)
BRIDGE_PROJECT=$(mktemp -d)

bridge_initial=$(
  CX_DASHBOARD_HOME="$BRIDGE_HOME/.cx/dashboard" \
    bash scripts/cx-dashboard-bridge.sh \
      --project-root "$BRIDGE_PROJECT" \
      --display-name "Bridge Smoke"
)
grep '^prompt_state=unknown$' <<< "$bridge_initial" >/dev/null
grep '^should_prompt=true$' <<< "$bridge_initial" >/dev/null
grep '^project_registered=false$' <<< "$bridge_initial" >/dev/null

bridge_accept=$(
  CX_DASHBOARD_HOME="$BRIDGE_HOME/.cx/dashboard" \
    bash scripts/cx-dashboard-bridge.sh \
      --project-root "$BRIDGE_PROJECT" \
      --display-name "Bridge Smoke" \
      --decision accept
)
grep '^prompt_state=accepted$' <<< "$bridge_accept" >/dev/null
grep '^auto_register=true$' <<< "$bridge_accept" >/dev/null
grep '^service_running=true$' <<< "$bridge_accept" >/dev/null
grep '^project_registered=true$' <<< "$bridge_accept" >/dev/null
bridge_frontend_url=$(grep '^frontend_url=' <<< "$bridge_accept" | head -n1 | cut -d= -f2-)
bridge_api_base_url=$(grep '^api_base_url=' <<< "$bridge_accept" | head -n1 | cut -d= -f2-)
test -n "$bridge_frontend_url"
test -n "$bridge_api_base_url"
curl -fsS -m 5 "$bridge_frontend_url" >/dev/null
curl -fsS -m 5 "$bridge_api_base_url/health" >/dev/null

bridge_follow_up=$(
  CX_DASHBOARD_HOME="$BRIDGE_HOME/.cx/dashboard" \
    bash scripts/cx-dashboard-bridge.sh \
      --project-root "$BRIDGE_PROJECT" \
      --display-name "Bridge Smoke"
)
grep '^should_prompt=false$' <<< "$bridge_follow_up" >/dev/null
grep '^project_registered=true$' <<< "$bridge_follow_up" >/dev/null
jq -e --arg root "$BRIDGE_PROJECT" '
  .prompt_state == "accepted"
  and .auto_register == true
  and any(.projects[]; .root_path == $root)
' "$BRIDGE_HOME/.cx/dashboard/registry.json" >/dev/null
if [[ -f "$BRIDGE_HOME/.cx/dashboard/backend.pid" ]]; then
  kill "$(cat "$BRIDGE_HOME/.cx/dashboard/backend.pid")" >/dev/null 2>&1 || true
fi
if [[ -f "$BRIDGE_HOME/.cx/dashboard/frontend.pid" ]]; then
  kill "$(cat "$BRIDGE_HOME/.cx/dashboard/frontend.pid")" >/dev/null 2>&1 || true
fi

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

echo "[check] core worktree recommendation records preferred checkout"
CORE_SCENARIO_DIR=$(mktemp -d)
cp -R tests/fixtures/core-dual-runner/. "$CORE_SCENARIO_DIR"
CX_CORE_NOW=2026-03-20T10:08:00Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-worktree.sh \
  --feature dual-runner-task-lock
jq -e '.binding_status == "recommended" and .preferred_worktree_path == "/worktrees/dual-runner-task-lock" and .preferred_branch == "codex/dual-runner-task-lock"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/worktrees/dual-runner-task-lock.json" >/dev/null
rm -rf "$CORE_SCENARIO_DIR"

echo "[check] core worktree binding succeeds for distinct features"
CORE_SCENARIO_DIR=$(mktemp -d)
cp -R tests/fixtures/core-dual-runner/. "$CORE_SCENARIO_DIR"
CX_CORE_NOW=2026-03-20T10:09:00Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-worktree.sh \
  --runner cc \
  --session-id cc-claim-002 \
  --branch cc/dual-runner-claim-b \
  --worktree-path /worktrees/dual-runner-claim-b \
  --current-branch cc/dual-runner-claim-b \
  --current-worktree-path /worktrees/dual-runner-claim-b \
  --feature dual-runner-claim-b
CX_CORE_NOW=2026-03-20T10:09:30Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-worktree.sh \
  --runner cc \
  --session-id cc-task-lock-002 \
  --branch cc/dual-runner-task-lock \
  --worktree-path /worktrees/dual-runner-task-lock \
  --current-branch cc/dual-runner-task-lock \
  --current-worktree-path /worktrees/dual-runner-task-lock \
  --feature dual-runner-task-lock
jq -e '.binding_status == "bound" and .preferred_worktree_path == "/worktrees/dual-runner-claim-b" and .runner == "cc" and .session_id == "cc-claim-002"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/worktrees/dual-runner-claim-b.json" >/dev/null
jq -e '.binding_status == "bound" and .preferred_worktree_path == "/worktrees/dual-runner-task-lock" and .runner == "cc" and .session_id == "cc-task-lock-002"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/worktrees/dual-runner-task-lock.json" >/dev/null
test "$(jq -r '.preferred_worktree_path' "$CORE_SCENARIO_DIR/.claude/cx/core/worktrees/dual-runner-claim-b.json")" != \
  "$(jq -r '.preferred_worktree_path' "$CORE_SCENARIO_DIR/.claude/cx/core/worktrees/dual-runner-task-lock.json")"
jq -e '.worktree.binding_status == "bound" and .worktree.worktree_path == "/worktrees/dual-runner-claim-b"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/features/dual-runner-claim-b.json" >/dev/null
jq -e '.worktree.binding_status == "bound" and .worktree.worktree_path == "/worktrees/dual-runner-task-lock"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/features/dual-runner-task-lock.json" >/dev/null
rm -rf "$CORE_SCENARIO_DIR"

echo "[check] workflow prd runner scaffolds feature and shared core deterministically"
WORKFLOW_SCENARIO_DIR=$(mktemp -d)
git -C "$WORKFLOW_SCENARIO_DIR" init >/dev/null 2>&1
(
  cd "$WORKFLOW_SCENARIO_DIR"
  bash "$REPO_ROOT/scripts/cx-init-setup.sh" \
    --developer-id smoke \
    --github-sync local \
    --agent-teams false \
    --code-review true \
    --worktree-isolation true \
    --auto-memory true >/dev/null
)
CX_CORE_NOW=2026-03-20T10:10:00Z CX_WORKFLOW_NOW=2026-03-20T10:10:00Z bash scripts/cx-workflow-prd.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --title "共享工作流冒烟" \
  --slug "workflow-smoke" \
  --runner codex \
  --session-id codex-prd-001 \
  --size M \
  --background "验证 shared workflow core 的 PRD 落盘。" \
  --scenarios "Codex 发起 feature|Claude Code 接手执行" \
  --requirements "生成最小 PRD|注册 shared core" \
  --acceptance "需求文档存在|shared core feature 已注册" \
  --decision-basis "M 规模默认需要设计。" >/dev/null
test -f "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/需求.md"
test -f "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/状态.json"
test -f "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/features/workflow-smoke.json"
test -f "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/worktrees/workflow-smoke.json"
jq -e '.current_feature == "workflow-smoke"' "$WORKFLOW_SCENARIO_DIR/.claude/cx/状态.json" >/dev/null
jq -e '.features["workflow-smoke"].status == "drafting"' "$WORKFLOW_SCENARIO_DIR/.claude/cx/状态.json" >/dev/null
jq -e '.features["workflow-smoke"].workflow_phase == "prd" and .features["workflow-smoke"].next_route == "cx-design"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/projects/project.json" >/dev/null
jq -e '.workflow.current_phase == "prd" and .workflow.next_route == "cx-design" and .workflow.needs_design == true and .workflow.size == "M"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/状态.json" >/dev/null
jq -e '.workflow.current_phase == "prd" and .workflow.next_route == "cx-design" and .workflow.needs_design == true and .planning_owner.runner == "codex" and .planning_owner.session_id == "codex-prd-001"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/features/workflow-smoke.json" >/dev/null

echo "[check] workflow design runner writes design doc and advances next route"
CX_CORE_NOW=2026-03-20T10:10:30Z CX_WORKFLOW_NOW=2026-03-20T10:10:30Z bash scripts/cx-workflow-design.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-design-001 \
  --decision-basis "设计契约已确认，可以进入任务规划。" >/dev/null
test -f "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/设计.md"
jq -e '.status == "planned" and .docs.design == "设计.md" and .workflow.current_phase == "design" and .workflow.next_route == "cx-plan"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/状态.json" >/dev/null
jq -e '.lifecycle.stage == "planned" and .docs.design == ".claude/cx/功能/共享工作流冒烟/设计.md" and .workflow.current_phase == "design" and .workflow.next_route == "cx-plan" and .planning_owner.session_id == "codex-design-001"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/features/workflow-smoke.json" >/dev/null

cat > "$WORKFLOW_SCENARIO_DIR/plan.json" <<'EOF'
{
  "phases": [
    {"number": 1, "name": "协议与规划"},
    {"number": 2, "name": "执行闭环", "depends_on": [1]}
  ],
  "tasks": [
    {
      "number": 1,
      "title": "写任务图",
      "phase": 1,
      "parallel": false,
      "depends_on": [],
      "goal": "生成任务拆分。",
      "modified_files": ["core/workflow/protocols/plan.md"],
      "created_files": [".claude/cx/功能/共享工作流冒烟/任务/任务-1.md"],
      "test_files": ["scripts/validate-cx-workflow.sh"],
      "acceptance": ["任务图完成", "任务文档完成"],
      "api_contracts": ["无"],
      "enum_contracts": ["无"],
      "field_mappings": ["无"]
    },
    {
      "number": 2,
      "title": "推进执行态 A",
      "phase": 2,
      "parallel": true,
      "depends_on": [1],
      "parallel_group": "exec-fanout",
      "goal": "更新执行状态 A。",
      "modified_files": ["scripts/cx-workflow-exec.sh"],
      "created_files": [],
      "test_files": ["scripts/validate-cx-workflow.sh"],
      "acceptance": ["执行 A 能开始", "执行 A 能完成"],
      "api_contracts": ["无"],
      "enum_contracts": ["无"],
      "field_mappings": ["无"]
    },
    {
      "number": 3,
      "title": "推进执行态 B",
      "phase": 2,
      "parallel": true,
      "depends_on": [1],
      "parallel_group": "exec-fanout",
      "goal": "更新执行状态 B。",
      "modified_files": ["scripts/cx-workflow-exec-dispatch.sh"],
      "created_files": [],
      "test_files": ["scripts/validate-cx-workflow.sh"],
      "acceptance": ["执行 B 能开始", "执行 B 能完成"],
      "api_contracts": ["无"],
      "enum_contracts": ["无"],
      "field_mappings": ["无"]
    }
  ]
}
EOF

echo "[check] workflow plan runner writes task docs and ready state"
CX_CORE_NOW=2026-03-20T10:11:00Z CX_WORKFLOW_NOW=2026-03-20T10:11:00Z bash scripts/cx-workflow-plan.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-plan-001 \
  --plan-json-file "$WORKFLOW_SCENARIO_DIR/plan.json" >/dev/null
test -f "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/任务/任务-1.md"
test -f "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/任务/任务-2.md"
test -f "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/任务/任务-3.md"
jq -e '.status == "planned" and .workflow.current_phase == "plan" and .workflow.next_route == "cx-exec"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/状态.json" >/dev/null
jq -e '.tasks[0].status == "ready" and .tasks[1].status == "pending" and .tasks[2].status == "pending"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/状态.json" >/dev/null
jq -e '.lifecycle.stage == "ready" and .workflow.current_phase == "plan" and .workflow.next_route == "cx-exec"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/features/workflow-smoke.json" >/dev/null
jq -e '.tasks[0].status == "ready" and .tasks[1].status == "pending" and .tasks[2].status == "pending"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/features/workflow-smoke.json" >/dev/null

echo "[check] workflow exec dispatch chooses next work instead of stopping at task boundary"
DISPATCH_OUTPUT=$(bash scripts/cx-workflow-exec-dispatch.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --mode auto)
printf '%s\n' "$DISPATCH_OUTPUT" | rg '^decision=continue$'
printf '%s\n' "$DISPATCH_OUTPUT" | rg '^selected_tasks=1$'

echo "[check] workflow exec runner advances tasks and unlocks dependencies"
CX_CORE_NOW=2026-03-20T10:12:00Z CX_WORKFLOW_NOW=2026-03-20T10:12:00Z bash scripts/cx-workflow-exec.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --branch codex/workflow-smoke \
  --worktree-path /worktrees/workflow-smoke \
  --action start \
  --task 1 >/dev/null
jq -e '.status == "executing" and .in_progress == 1 and .tasks[0].status == "in_progress"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/状态.json" >/dev/null
jq -e '.lifecycle.stage == "executing" and .lease.session_id == "codex-exec-001" and .tasks[0].status == "in_progress"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/features/workflow-smoke.json" >/dev/null

CX_CORE_NOW=2026-03-20T10:13:00Z CX_WORKFLOW_NOW=2026-03-20T10:13:00Z bash scripts/cx-workflow-exec.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --branch codex/workflow-smoke \
  --worktree-path /worktrees/workflow-smoke \
  --action complete \
  --task 1 \
  --commit abc123 >/dev/null
jq -e '.completed == 1 and .in_progress == 0 and .tasks[0].status == "completed" and .tasks[0].commit == "abc123" and .tasks[1].status == "ready"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/状态.json" >/dev/null
jq -e '.lifecycle.stage == "executing" and .lease.claimed_tasks == [] and .tasks[0].status == "completed" and .tasks[1].status == "ready" and .tasks[2].status == "ready"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/features/workflow-smoke.json" >/dev/null

echo "[check] workflow exec dispatch surfaces parallel-ready choice after task completion"
DISPATCH_OUTPUT=$(bash scripts/cx-workflow-exec-dispatch.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --mode auto)
printf '%s\n' "$DISPATCH_OUTPUT" | rg '^decision=ask_parallel$'
printf '%s\n' "$DISPATCH_OUTPUT" | rg '^selected_tasks=2$'
printf '%s\n' "$DISPATCH_OUTPUT" | rg '^parallel_tasks=2,3$'
printf '%s\n' "$DISPATCH_OUTPUT" | rg '^recommended_mode=sequential$'

DISPATCH_OUTPUT=$(bash scripts/cx-workflow-exec-dispatch.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --mode all)
printf '%s\n' "$DISPATCH_OUTPUT" | rg '^decision=parallel$'
printf '%s\n' "$DISPATCH_OUTPUT" | rg '^selected_tasks=2,3$'

CX_CORE_NOW=2026-03-20T10:14:00Z CX_WORKFLOW_NOW=2026-03-20T10:14:00Z bash scripts/cx-workflow-exec.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --branch codex/workflow-smoke \
  --worktree-path /worktrees/workflow-smoke \
  --action start \
  --task 2 >/dev/null
CX_CORE_NOW=2026-03-20T10:14:30Z CX_WORKFLOW_NOW=2026-03-20T10:14:30Z bash scripts/cx-workflow-exec.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --branch codex/workflow-smoke \
  --worktree-path /worktrees/workflow-smoke \
  --action complete \
  --task 2 \
  --commit def456 >/dev/null
DISPATCH_OUTPUT=$(bash scripts/cx-workflow-exec-dispatch.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --mode auto)
printf '%s\n' "$DISPATCH_OUTPUT" | rg '^decision=continue$'
printf '%s\n' "$DISPATCH_OUTPUT" | rg '^selected_tasks=3$'
CX_CORE_NOW=2026-03-20T10:15:00Z CX_WORKFLOW_NOW=2026-03-20T10:15:00Z bash scripts/cx-workflow-exec.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --branch codex/workflow-smoke \
  --worktree-path /worktrees/workflow-smoke \
  --action start \
  --task 3 >/dev/null
CX_CORE_NOW=2026-03-20T10:15:30Z CX_WORKFLOW_NOW=2026-03-20T10:15:30Z bash scripts/cx-workflow-exec.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --branch codex/workflow-smoke \
  --worktree-path /worktrees/workflow-smoke \
  --action complete \
  --task 3 \
  --commit ghi789 >/dev/null
jq -e '.status == "completed" and .completed == 3 and .workflow.next_route == "cx-summary" and .tasks[1].commit == "def456" and .tasks[2].commit == "ghi789"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/状态.json" >/dev/null
jq -e '.lifecycle.stage == "completed" and .workflow.next_route == "cx-summary" and .lease.claimed_tasks == []' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/features/workflow-smoke.json" >/dev/null

echo "[check] workflow status runner summarizes shared state and writes runtime snapshot"
STATUS_OUTPUT=$(CX_CORE_NOW=2026-03-20T10:15:30Z CX_WORKFLOW_NOW=2026-03-20T10:15:30Z bash scripts/cx-workflow-status.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex)
printf '%s\n' "$STATUS_OUTPUT" | rg 'current_feature=workflow-smoke'
printf '%s\n' "$STATUS_OUTPUT" | rg 'next_route=cx-summary'
printf '%s\n' "$STATUS_OUTPUT" | rg 'owner_runner=codex'
test -f "$WORKFLOW_SCENARIO_DIR/.claude/cx/runtime/codex/当前状态.json"
jq -e '.current_feature.slug == "workflow-smoke" and .current_feature.next_route == "cx-summary"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/runtime/codex/当前状态.json" >/dev/null

echo "[check] workflow summary runner archives completed feature"
CX_CORE_NOW=2026-03-20T10:16:00Z CX_WORKFLOW_NOW=2026-03-20T10:16:00Z bash scripts/cx-workflow-summary.sh \
  --project-root "$WORKFLOW_SCENARIO_DIR" \
  --feature workflow-smoke \
  --runner codex \
  --session-id codex-exec-001 \
  --deliverables "任务拆分完成|执行状态推进完成|共享闭环已归档" \
  --test-command "bash scripts/validate-cx-workflow.sh" \
  --test-result "通过" \
  --review-result "通过" >/dev/null
test -f "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/总结.md"
jq -e '.status == "summarized" and .workflow.current_phase == "summary" and .workflow.completion_status == "done" and .workflow.next_route == null' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/功能/共享工作流冒烟/状态.json" >/dev/null
jq -e '.lifecycle.stage == "archived" and .workflow.current_phase == "summary" and .workflow.completion_status == "done" and .workflow.next_route == null and .worktree.binding_status == "released"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/features/workflow-smoke.json" >/dev/null
jq -e '.current_feature == null and .features["workflow-smoke"].status == "summarized"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/状态.json" >/dev/null
jq -e '.current_feature == null and .features["workflow-smoke"].lifecycle == "archived" and .features["workflow-smoke"].lease_session_id == null and .active_sessions["codex-exec-001"].claimed_feature == null and .active_sessions["codex-exec-001"].claimed_tasks == []' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/projects/project.json" >/dev/null
jq -e '.binding_status == "released"' \
  "$WORKFLOW_SCENARIO_DIR/.claude/cx/core/worktrees/workflow-smoke.json" >/dev/null
rm -rf "$WORKFLOW_SCENARIO_DIR"

echo "[check] workflow fix runner writes standalone fix record"
FIX_SCENARIO_DIR=$(mktemp -d)
git -C "$FIX_SCENARIO_DIR" init >/dev/null 2>&1
(
  cd "$FIX_SCENARIO_DIR"
  bash "$REPO_ROOT/scripts/cx-init-setup.sh" \
    --developer-id smoke \
    --github-sync local \
    --agent-teams false \
    --code-review true \
    --worktree-isolation true \
    --auto-memory true >/dev/null
)
CX_CORE_NOW=2026-03-20T10:16:30Z CX_WORKFLOW_NOW=2026-03-20T10:16:30Z bash scripts/cx-workflow-fix.sh \
  --project-root "$FIX_SCENARIO_DIR" \
  --title "共享状态小修复" \
  --slug core-fix-smoke \
  --runner codex \
  --problem "status 输出缺少统一快照" \
  --root-cause "缺少共享 fix runner" \
  --resolution "新增 shared fix runner|补齐 fixes 索引" \
  --verification-command "bash scripts/validate-cx-workflow.sh" \
  --verification-result "通过" \
  --commit abcfix >/dev/null
test -f "$FIX_SCENARIO_DIR/.claude/cx/修复/共享状态小修复/修复记录.md"
jq -e '.fixes["core-fix-smoke"].title == "共享状态小修复" and .fixes["core-fix-smoke"].path == "修复/共享状态小修复"' \
  "$FIX_SCENARIO_DIR/.claude/cx/状态.json" >/dev/null
rm -rf "$FIX_SCENARIO_DIR"

echo "[check] core worktree binding rejects wrong checkout for same feature"
CORE_SCENARIO_DIR=$(mktemp -d)
cp -R tests/fixtures/core-dual-runner/. "$CORE_SCENARIO_DIR"
if CX_CORE_NOW=2026-03-20T10:10:00Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-worktree.sh \
  --runner cc \
  --session-id cc-claim-003 \
  --branch cc/dual-runner-claim-a \
  --worktree-path /worktrees/dual-runner-claim-a \
  --current-branch cc/dual-runner-claim-a \
  --current-worktree-path /worktrees/dual-runner-claim-b \
  --feature dual-runner-claim-a; then
  echo "wrong worktree binding should fail" >&2
  rm -rf "$CORE_SCENARIO_DIR"
  exit 1
fi
jq -e '.binding_status == "bound" and .preferred_worktree_path == "/worktrees/dual-runner-claim-a"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/worktrees/dual-runner-claim-a.json" >/dev/null
rm -rf "$CORE_SCENARIO_DIR"

echo "[check] cc adapter surfaces codex-owned feature without stealing"
CORE_SCENARIO_DIR=$(mktemp -d)
cp -R tests/fixtures/core-dual-runner/. "$CORE_SCENARIO_DIR"
SESSION_OUTPUT=$(PROJECT_ROOT="$CORE_SCENARIO_DIR" bash hooks/session-start.sh)
printf '%s\n' "$SESSION_OUTPUT" | rg 'codex-claim-001'
printf '%s\n' "$SESSION_OUTPUT" | rg 'handoff'
if CX_CORE_NOW=2026-03-20T10:10:30Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-worktree.sh \
  --runner cc \
  --session-id cc-steal-001 \
  --branch cc/dual-runner-claim-a \
  --worktree-path /worktrees/dual-runner-claim-a \
  --current-branch cc/dual-runner-claim-a \
  --current-worktree-path /worktrees/dual-runner-claim-a \
  --feature dual-runner-claim-a; then
  echo "cc adapter should not silently steal a codex-owned feature" >&2
  rm -rf "$CORE_SCENARIO_DIR"
  exit 1
fi
rm -rf "$CORE_SCENARIO_DIR"

echo "[check] cc adapter can accept handoff and continue"
CORE_SCENARIO_DIR=$(mktemp -d)
cp -R tests/fixtures/core-dual-runner/. "$CORE_SCENARIO_DIR"
jq '.runner = "cc"
  | .session_id = "cc-accept-001"
  | .branch = "cc/dual-runner-claim-a"
  | .worktree_path = "/worktrees/dual-runner-claim-a"
  | .claimed_feature = null
  | .claimed_tasks = []' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/sessions/cc-source-001.json" > "$CORE_SCENARIO_DIR/cc-accept-001.json"
mv "$CORE_SCENARIO_DIR/cc-accept-001.json" "$CORE_SCENARIO_DIR/.claude/cx/core/sessions/cc-accept-001.json"
jq --slurpfile session "$CORE_SCENARIO_DIR/.claude/cx/core/sessions/cc-accept-001.json" \
  '.active_sessions["cc-accept-001"] = $session[0]' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/projects/core-dual-runner.json" > "$CORE_SCENARIO_DIR/project.json"
mv "$CORE_SCENARIO_DIR/project.json" "$CORE_SCENARIO_DIR/.claude/cx/core/projects/core-dual-runner.json"
CX_CORE_NOW=2026-03-20T10:10:40Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-handoff.sh \
  --source-runner codex \
  --source-session-id codex-claim-001 \
  --target-runner cc \
  --target-session-id cc-accept-001 \
  --feature dual-runner-claim-a \
  --reason "cc adapter accepts the feature and continues"
CX_CORE_NOW=2026-03-20T10:10:50Z PROJECT_ROOT="$CORE_SCENARIO_DIR" bash scripts/cx-core-worktree.sh \
  --runner cc \
  --session-id cc-accept-001 \
  --branch cc/dual-runner-claim-a \
  --worktree-path /worktrees/dual-runner-claim-a \
  --current-branch cc/dual-runner-claim-a \
  --current-worktree-path /worktrees/dual-runner-claim-a \
  --feature dual-runner-claim-a
jq -e '.features["dual-runner-claim-a"].lease_session_id == "cc-accept-001"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/projects/core-dual-runner.json" >/dev/null
jq -e '.execution_owner.runner == "cc" and .execution_owner.session_id == "cc-accept-001"' \
  "$CORE_SCENARIO_DIR/.claude/cx/core/features/dual-runner-claim-a.json" >/dev/null
PROMPT_OUTPUT=$(PROJECT_ROOT="$CORE_SCENARIO_DIR" bash hooks/prompt-submit.sh)
test -z "$PROMPT_OUTPUT"
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
  rg '每个项目都单独确认 developer_id' skills/cx-init/SKILL.md

  echo "[check] cx-init suggests creating GitHub remote"
  rg '默认建议创建 GitHub 仓库并绑定' skills/cx-init/SKILL.md

  echo "[check] cx-init uses project-level 配置.json wording"
  rg '配置.json' skills/cx-init/SKILL.md

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
  rg '配置.json|状态.json|功能/|runtime/cc' hooks/cx-runtime.sh hooks/session-start.sh hooks/pre-compact.sh hooks/prompt-submit.sh hooks/post-edit.sh hooks/stop-check.sh hooks/stop-failure.sh hooks/config-change.sh

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
  rm -f tests/fixtures/minimal-project/.claude/cx/runtime/cc/context-snapshot.md
  PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/pre-compact.sh
  test -f tests/fixtures/minimal-project/.claude/cx/runtime/cc/context-snapshot.md
  ! test -f tests/fixtures/minimal-project/.claude/cx/context-snapshot.md
  rg 'sample-feature' tests/fixtures/minimal-project/.claude/cx/runtime/cc/context-snapshot.md

  echo "[check] prompt-submit stays quiet during normal execution"
  PROMPT_OUTPUT=$(PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/prompt-submit.sh)
  test -z "$PROMPT_OUTPUT"

  echo "[check] stop hook reminds unfinished feature"
  STOP_OUTPUT=$(PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/stop-check.sh)
  printf '%s\n' "$STOP_OUTPUT" | rg '/cx:cx-exec'

  echo "[check] stop-failure writes failure snapshot"
  rm -f tests/fixtures/minimal-project/.claude/cx/runtime/cc/最近失败.json
  printf '%s' '{"error":"rate_limit","message":"Too many requests"}' | PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/stop-failure.sh
  test -f tests/fixtures/minimal-project/.claude/cx/runtime/cc/最近失败.json
  rg '"error": "rate_limit"' tests/fixtures/minimal-project/.claude/cx/runtime/cc/最近失败.json
  rg '"runner": "cc"' tests/fixtures/minimal-project/.claude/cx/runtime/cc/最近失败.json

  echo "[check] config-change writes config snapshot"
  rm -f tests/fixtures/minimal-project/.claude/cx/runtime/cc/最近配置变更.json
  printf '%s' '{"source":"project_settings","file_path":".claude/settings.json"}' | PROJECT_ROOT=tests/fixtures/minimal-project bash hooks/config-change.sh
  test -f tests/fixtures/minimal-project/.claude/cx/runtime/cc/最近配置变更.json
  rg '"source": "project_settings"' tests/fixtures/minimal-project/.claude/cx/runtime/cc/最近配置变更.json
  rg '"runner": "cc"' tests/fixtures/minimal-project/.claude/cx/runtime/cc/最近配置变更.json

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
rg '自动判断是否需要 Design' skills/cx-prd/SKILL.md
rg '仅当 PRD 明显引入新技术时' skills/cx-plan/SKILL.md
! rg -F '{dev_id}-{feature}' skills/cx-prd/SKILL.md skills/cx-design/SKILL.md skills/cx-adr/SKILL.md skills/cx-plan/SKILL.md
rg '功能/' references/templates/prd.md references/templates/design.md references/templates/task.md
rg 'shared workflow core|cx-workflow-prd.sh|core/workflow/protocols/prd.md' skills/cx-prd/SKILL.md
rg 'core/workflow/protocols/design.md' skills/cx-design/SKILL.md
rg 'core/workflow/protocols/plan.md' skills/cx-plan/SKILL.md

echo "[check] execution chain follows pure cx 3.1 semantics"
rg '/cx:cx-exec --all' skills/cx-exec/SKILL.md
rg -F '3+ 专业代理' skills/cx-exec/SKILL.md
rg -F '[cx:<feature-slug>] [task:<n>]' skills/cx-exec/SKILL.md
rg 'worktree 校验|当前 checkout 与 feature 绑定一致' skills/cx-exec/SKILL.md
rg 'preferred_worktree_path|binding_status' skills/cx-plan/SKILL.md
rg 'reason_type' skills/cx-status/SKILL.md skills/cx-exec/SKILL.md
rg 'GitHub 为同步镜像' skills/cx-summary/SKILL.md skills/cx-help/SKILL.md
rg 'core/workflow/protocols/exec.md' skills/cx-exec/SKILL.md
rg 'core/workflow/protocols/fix.md' skills/cx-fix/SKILL.md
rg 'core/workflow/protocols/status.md' skills/cx-status/SKILL.md
rg 'core/workflow/protocols/summary.md' skills/cx-summary/SKILL.md
rg 'cx-workflow-design.sh' skills/cx-design/SKILL.md adapters/codex/skills/cx-design/SKILL.md
rg 'cx-workflow-fix.sh' skills/cx-fix/SKILL.md adapters/codex/skills/cx-fix/SKILL.md
rg 'cx-workflow-status.sh' skills/cx-status/SKILL.md adapters/codex/skills/cx-status/SKILL.md
rg 'cx-workflow-summary.sh' skills/cx-summary/SKILL.md adapters/codex/skills/cx-summary/SKILL.md
rg 'runner `cc`|共享 core|handoff' skills/cx-init/SKILL.md skills/cx-prd/SKILL.md skills/cx-design/SKILL.md skills/cx-adr/SKILL.md skills/cx-plan/SKILL.md skills/cx-exec/SKILL.md skills/cx-fix/SKILL.md skills/cx-status/SKILL.md skills/cx-summary/SKILL.md references/workflow-guide.md
rg '配置.json' skills/cx-config/SKILL.md
! rg 'background_agents|prompt_refresh_interval' skills/cx-config/SKILL.md
rg 'disable-model-invocation: true' skills/cx-init/SKILL.md skills/cx-prd/SKILL.md skills/cx-fix/SKILL.md skills/cx-config/SKILL.md skills/cx-scope/SKILL.md
! rg 'disable-model-invocation: true' skills/cx-design/SKILL.md skills/cx-adr/SKILL.md skills/cx-plan/SKILL.md skills/cx-exec/SKILL.md skills/cx-summary/SKILL.md
rg '自动衔接到本 skill' skills/cx-design/SKILL.md skills/cx-adr/SKILL.md skills/cx-plan/SKILL.md skills/cx-exec/SKILL.md skills/cx-summary/SKILL.md
rg -F 'preferred worktree' references/core-schema-overview.md references/workflow-guide.md
rg -F 'handoff' references/core-schema-overview.md references/workflow-guide.md
rg -F '在 claim 前先调用 worktree 绑定检查' references/workflow-guide.md
rg '修复/' references/templates/fix.md
rg '总结.md' references/templates/summary.md

echo "[check] codex adapter docs exist and describe dual-runner contract"
test -f docs/codex-adapter-guide.md
test -f references/codex-skill-contract.md
rg 'runner `codex`|lease|handoff|worktree' docs/codex-adapter-guide.md references/codex-skill-contract.md
rg 'CC 创建 feature A.*Codex 创建 feature B|CC 规划.*Codex 执行|Codex 规划.*CC 执行|中途 handoff' docs/codex-adapter-guide.md references/workflow-guide.md

echo "[check] codex adapter package exists"
test -f adapters/codex/README.md
test -f scripts/install-codex.sh
bash -n scripts/install-codex.sh
for skill in help init prd design adr plan exec fix status summary config scope; do
  test -f "adapters/codex/skills/cx-$skill/SKILL.md"
  test -f "adapters/codex/skills/cx-$skill/agents/openai.yaml"
done
rg 'cx-shared|runtime/codex|handoff|lease|worktree' adapters/codex/skills/cx-*/SKILL.md
rg 'core/workflow/protocols/prd.md' adapters/codex/skills/cx-prd/SKILL.md
rg 'core/workflow/protocols/exec.md' adapters/codex/skills/cx-exec/SKILL.md
rg 'display_name|short_description|default_prompt' adapters/codex/skills/cx-*/agents/openai.yaml

echo "[check] install-codex.sh installs user-scope bundle"
CODEX_INSTALL_TMP=$(mktemp -d)
bash scripts/install-codex.sh --target-root "$CODEX_INSTALL_TMP/.agents/skills"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-help/SKILL.md"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-exec/agents/openai.yaml"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/core/workflow/README.md"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/core/workflow/protocols/prd.md"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/references/codex-skill-contract.md"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/scripts/cx-core-claim.sh"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/scripts/cx-workflow-prd.sh"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/scripts/cx-workflow-plan.sh"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/scripts/cx-workflow-exec.sh"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/scripts/cx-workflow-exec-dispatch.sh"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/scripts/cx-workflow-design.sh"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/scripts/cx-workflow-status.sh"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/scripts/cx-workflow-summary.sh"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-shared/scripts/cx-workflow-fix.sh"
rg 'runtime/codex' "$CODEX_INSTALL_TMP/.agents/skills/cx-exec/SKILL.md"
rm -rf "$CODEX_INSTALL_TMP"

echo "[check] install-codex.sh can mirror to legacy codex skills path"
CODEX_INSTALL_TMP=$(mktemp -d)
bash scripts/install-codex.sh --target-root "$CODEX_INSTALL_TMP/.agents/skills" --legacy-target-root "$CODEX_INSTALL_TMP/.codex/skills"
test -f "$CODEX_INSTALL_TMP/.agents/skills/cx-status/SKILL.md"
test -f "$CODEX_INSTALL_TMP/.codex/skills/cx-status/SKILL.md"
test -f "$CODEX_INSTALL_TMP/.codex/skills/cx-shared/core/workflow/protocols/summary.md"
test -f "$CODEX_INSTALL_TMP/.codex/skills/cx-shared/scripts/cx-core-migrate.sh"
test -f "$CODEX_INSTALL_TMP/.codex/skills/cx-shared/scripts/cx-workflow-exec-dispatch.sh"
test -f "$CODEX_INSTALL_TMP/.codex/skills/cx-shared/scripts/cx-workflow-plan.sh"
test -f "$CODEX_INSTALL_TMP/.codex/skills/cx-shared/scripts/cx-workflow-exec.sh"
test -f "$CODEX_INSTALL_TMP/.codex/skills/cx-shared/scripts/cx-workflow-design.sh"
test -f "$CODEX_INSTALL_TMP/.codex/skills/cx-shared/scripts/cx-workflow-status.sh"
test -f "$CODEX_INSTALL_TMP/.codex/skills/cx-shared/scripts/cx-workflow-summary.sh"
test -f "$CODEX_INSTALL_TMP/.codex/skills/cx-shared/scripts/cx-workflow-fix.sh"
rm -rf "$CODEX_INSTALL_TMP"

echo "[check] migration helper upgrades legacy projects into shared core"
test -f scripts/cx-core-migrate.sh
bash -n scripts/cx-core-migrate.sh
MIGRATION_TMP_DIR=$(mktemp -d)
cp -R tests/fixtures/core-dual-runner/legacy-project/. "$MIGRATION_TMP_DIR"
CX_CORE_NOW=2026-03-20T10:20:00Z PROJECT_ROOT="$MIGRATION_TMP_DIR" bash scripts/cx-core-migrate.sh
jq empty \
  "$MIGRATION_TMP_DIR/.claude/cx/core/projects/project.json" \
  "$MIGRATION_TMP_DIR/.claude/cx/core/features/vector-memory.json" \
  "$MIGRATION_TMP_DIR/.claude/cx/core/worktrees/vector-memory.json"
jq -e '.current_feature == "vector-memory"' "$MIGRATION_TMP_DIR/.claude/cx/core/projects/project.json" >/dev/null
jq -e '.features["vector-memory"].slug == "vector-memory"' "$MIGRATION_TMP_DIR/.claude/cx/core/projects/project.json" >/dev/null
jq -e '.title == "向量记忆" and .docs.prd == "需求.md" and .docs.design == "设计.md" and .docs.summary == "总结.md"' \
  "$MIGRATION_TMP_DIR/.claude/cx/core/features/vector-memory.json" >/dev/null
jq -e '.tasks[0].id == 1 and .tasks[1].status == "in_progress"' \
  "$MIGRATION_TMP_DIR/.claude/cx/core/features/vector-memory.json" >/dev/null
test -f "$MIGRATION_TMP_DIR/.claude/cx/runtime/cc/最近失败.json"
test -f "$MIGRATION_TMP_DIR/.claude/cx/runtime/cc/最近配置变更.json"
test -f "$MIGRATION_TMP_DIR/.claude/cx/runtime/cc/context-snapshot.md"
! test -f "$MIGRATION_TMP_DIR/.claude/cx/最近失败.json"
! test -f "$MIGRATION_TMP_DIR/.claude/cx/最近配置变更.json"
! test -f "$MIGRATION_TMP_DIR/.claude/cx/context-snapshot.md"
rm -rf "$MIGRATION_TMP_DIR"

echo "[check] migration helper normalizes english legacy layout into chinese public runtime"
LEGACY_EN_TMP_DIR=$(mktemp -d)
mkdir -p "$LEGACY_EN_TMP_DIR/.claude/cx/features/vector-memory/tasks"
cat > "$LEGACY_EN_TMP_DIR/.claude/cx/config.json" <<'EOF'
{
  "version": "3.0",
  "developer_id": "chengxuan",
  "github_sync": "local",
  "current_feature": "chengxuan-vector-memory",
  "agent_teams": true,
  "code_review": true,
  "auto_memory": true,
  "worktree_isolation": true,
  "auto_format": {
    "enabled": true,
    "formatter": "auto"
  },
  "hooks": {
    "session_start": true,
    "pre_compact": true,
    "post_edit_format": true,
    "notification": true
  }
}
EOF
cat > "$LEGACY_EN_TMP_DIR/.claude/cx/status.json" <<'EOF'
{
  "initialized_at": "2026-03-10T10:00:00Z",
  "last_updated": "2026-03-10T10:00:00Z",
  "current_feature": "chengxuan-vector-memory",
  "features": {
    "chengxuan-vector-memory": {
      "title": "向量记忆",
      "path": "features/vector-memory",
      "status": "executing"
    }
  },
  "fixes": []
}
EOF
cat > "$LEGACY_EN_TMP_DIR/.claude/cx/features/vector-memory/prd.md" <<'EOF'
# PRD
EOF
cat > "$LEGACY_EN_TMP_DIR/.claude/cx/features/vector-memory/design.md" <<'EOF'
# Design
EOF
cat > "$LEGACY_EN_TMP_DIR/.claude/cx/features/vector-memory/summary.md" <<'EOF'
# Summary
EOF
cat > "$LEGACY_EN_TMP_DIR/.claude/cx/features/vector-memory/status.json" <<'EOF'
{
  "feature": "向量记忆",
  "slug": "chengxuan-vector-memory",
  "created_at": "2026-03-10T10:00:00Z",
  "last_updated": "2026-03-10T10:00:00Z",
  "status": "executing",
  "total": 1,
  "completed": 0,
  "in_progress": 1,
  "phases": [
    {
      "number": 1,
      "name": "基础阶段",
      "status": "in_progress",
      "tasks": [1]
    }
  ],
  "tasks": [
    {
      "number": 1,
      "title": "迁移英文布局",
      "phase": 1,
      "parallel": false,
      "depends_on": [],
      "status": "in_progress"
    }
  ],
  "execution_order": [1]
}
EOF
cat > "$LEGACY_EN_TMP_DIR/.claude/cx/features/vector-memory/tasks/task-1.md" <<'EOF'
# Task 1
EOF
CX_CORE_NOW=2026-03-20T10:20:00Z PROJECT_ROOT="$LEGACY_EN_TMP_DIR" bash scripts/cx-core-migrate.sh
jq empty \
  "$LEGACY_EN_TMP_DIR/.claude/cx/配置.json" \
  "$LEGACY_EN_TMP_DIR/.claude/cx/状态.json" \
  "$LEGACY_EN_TMP_DIR/.claude/cx/功能/向量记忆/状态.json"
jq -e '.current_feature == "vector-memory"' "$LEGACY_EN_TMP_DIR/.claude/cx/配置.json" >/dev/null
jq -e '.current_feature == "vector-memory"' "$LEGACY_EN_TMP_DIR/.claude/cx/状态.json" >/dev/null
jq -e '.features["vector-memory"].path == "功能/向量记忆"' "$LEGACY_EN_TMP_DIR/.claude/cx/状态.json" >/dev/null
test -f "$LEGACY_EN_TMP_DIR/.claude/cx/功能/向量记忆/需求.md"
test -f "$LEGACY_EN_TMP_DIR/.claude/cx/功能/向量记忆/设计.md"
test -f "$LEGACY_EN_TMP_DIR/.claude/cx/功能/向量记忆/总结.md"
test -f "$LEGACY_EN_TMP_DIR/.claude/cx/功能/向量记忆/任务/任务-1.md"
rm -rf "$LEGACY_EN_TMP_DIR"
rg 'cx-core-migrate.sh|先迁移' README.md references/workflow-guide.md skills/cx-init/SKILL.md

echo "[check] migration helper rebuilds feature index from legacy features when public status is sparse"
SPARSE_MIGRATION_TMP_DIR=$(mktemp -d)
mkdir -p "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/features/chengxuan-vector-memory/tasks"
cat > "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/配置.json" <<'EOF'
{
  "version": "3.0",
  "developer_id": "chengxuan",
  "github_sync": "local",
  "current_feature": "vector-memory",
  "agent_teams": true,
  "code_review": true,
  "auto_memory": true,
  "worktree_isolation": true,
  "auto_format": {
    "enabled": true,
    "formatter": "auto"
  },
  "hooks": {
    "session_start": true,
    "pre_compact": true,
    "post_edit_format": true,
    "notification": true
  }
}
EOF
cat > "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/状态.json" <<'EOF'
{
  "initialized_at": "2026-03-10T10:00:00Z",
  "last_updated": "2026-03-10T10:00:00Z",
  "current_feature": "vector-memory",
  "features": {
    "vector-memory": {
      "status": "executing"
    }
  },
  "fixes": {}
}
EOF
cat > "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/features/chengxuan-vector-memory/prd.json" <<'EOF'
{
  "feature_name": "向量记忆检索功能",
  "slug": "vector-memory",
  "created_at": "2026-03-10T10:00:00Z",
  "scale": "M"
}
EOF
cat > "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/features/chengxuan-vector-memory/prd.md" <<'EOF'
# PRD
EOF
cat > "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/features/chengxuan-vector-memory/design.md" <<'EOF'
# Design
EOF
cat > "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/features/chengxuan-vector-memory/summary.md" <<'EOF'
# Summary
EOF
cat > "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/features/chengxuan-vector-memory/status.json" <<'EOF'
{
  "feature": "向量记忆检索功能",
  "slug": "chengxuan-vector-memory",
  "created_at": "2026-03-10T10:00:00Z",
  "last_updated": "2026-03-10T10:00:00Z",
  "status": "executing",
  "total": 1,
  "completed": 0,
  "in_progress": 1,
  "phases": [
    {
      "number": 1,
      "name": "基础阶段",
      "status": "in_progress",
      "tasks": [1]
    }
  ],
  "tasks": [
    {
      "number": 1,
      "title": "兼容旧索引迁移",
      "phase": 1,
      "parallel": false,
      "depends_on": [],
      "status": "in_progress"
    }
  ],
  "execution_order": [1]
}
EOF
cat > "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/features/chengxuan-vector-memory/tasks/task-1.md" <<'EOF'
# Task 1
EOF
CX_CORE_NOW=2026-03-20T10:20:00Z PROJECT_ROOT="$SPARSE_MIGRATION_TMP_DIR" bash scripts/cx-core-migrate.sh
jq -e '.current_feature == "vector-memory"' "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/状态.json" >/dev/null
jq -e '.features["vector-memory"].title == "向量记忆检索功能"' "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/状态.json" >/dev/null
jq -e '.features["vector-memory"].path == "功能/向量记忆检索功能"' "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/状态.json" >/dev/null
jq -e '.features["vector-memory"].slug == "vector-memory"' "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/core/projects/project.json" >/dev/null
test -f "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/功能/向量记忆检索功能/状态.json"
test -f "$SPARSE_MIGRATION_TMP_DIR/.claude/cx/功能/向量记忆检索功能/需求.md"
rm -rf "$SPARSE_MIGRATION_TMP_DIR"

echo "[check] public docs and metadata present pure cx 3.1"
rg '"name": "cx"' .claude-plugin/plugin.json .claude-plugin/marketplace.json
rg '"version": "3.1.0"' .claude-plugin/plugin.json .claude-plugin/marketplace.json
rg '只保留 `cx`' README.md references/workflow-guide.md
! rg -F '/tc' README.md references/workflow-guide.md
rg '/cx:cx-init' README.md references/workflow-guide.md skills/cx-help/SKILL.md
rg 'shared workflow core|core/workflow' README.md references/workflow-guide.md docs/codex-adapter-guide.md adapters/codex/README.md
rg '纯 cx 3.1|/cx:\*|Codex skill adapter' README.md references/workflow-guide.md CHANGELOG.md
rg '2.1.79|Codex 侧必须同步|先迁移|\.agents/skills|install-codex.sh' README.md CHANGELOG.md docs/codex-adapter-guide.md references/workflow-guide.md
