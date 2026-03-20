#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

HOME_DIR="${HOME:-$(cd ~ && pwd)}"
DASHBOARD_BASE_DIR="${CX_DASHBOARD_HOME:-$HOME_DIR/.cx/dashboard}"
REGISTRY_PATH="${CX_DASHBOARD_REGISTRY_PATH:-$DASHBOARD_BASE_DIR/registry.json}"
RUNTIME_PATH="${CX_DASHBOARD_RUNTIME_PATH:-$DASHBOARD_BASE_DIR/runtime.json}"

run_bridge() {
  (
    cd "$REPO_ROOT/apps/dashboard-service" && \
      node --import tsx src/bridge.ts \
        --registry-path "$REGISTRY_PATH" \
        --runtime-path "$RUNTIME_PATH" \
        "$@"
  )
}

bridge_json=$(run_bridge "$@")
prompt_state=$(jq -r '.promptState' <<< "$bridge_json")
service_running=$(jq -r '.serviceRunning' <<< "$bridge_json")

if [[ "$prompt_state" == "accepted" && "$service_running" != "true" ]]; then
  bash "$SCRIPT_DIR/cx-dashboard-ensure.sh" >/dev/null
  bridge_json=$(run_bridge "$@")
fi

printf 'decision_applied=%s\n' "$(jq -r '.decisionApplied' <<< "$bridge_json")"
printf 'prompt_state=%s\n' "$(jq -r '.promptState' <<< "$bridge_json")"
printf 'auto_register=%s\n' "$(jq -r '.autoRegister' <<< "$bridge_json")"
printf 'should_prompt=%s\n' "$(jq -r '.shouldPrompt' <<< "$bridge_json")"
printf 'should_auto_register=%s\n' "$(jq -r '.shouldAutoRegister' <<< "$bridge_json")"
printf 'service_status=%s\n' "$(jq -r '.serviceStatus' <<< "$bridge_json")"
printf 'service_running=%s\n' "$(jq -r '.serviceRunning' <<< "$bridge_json")"
printf 'frontend_url=%s\n' "$(jq -r '.frontendUrl // empty' <<< "$bridge_json")"
printf 'api_base_url=%s\n' "$(jq -r '.apiBaseUrl // empty' <<< "$bridge_json")"
printf 'project_root=%s\n' "$(jq -r '.projectRoot // empty' <<< "$bridge_json")"
printf 'project_registered=%s\n' "$(jq -r '.projectRegistered' <<< "$bridge_json")"
printf 'project_id=%s\n' "$(jq -r '.projectId // empty' <<< "$bridge_json")"
printf 'registration_source=%s\n' "$(jq -r '.registrationSource // empty' <<< "$bridge_json")"
printf 'registry_path=%s\n' "$(jq -r '.registryPath' <<< "$bridge_json")"
printf 'runtime_path=%s\n' "$(jq -r '.runtimePath' <<< "$bridge_json")"
