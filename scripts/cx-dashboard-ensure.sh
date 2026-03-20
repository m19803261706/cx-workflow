#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

HOME_DIR="${HOME:-$(cd ~ && pwd)}"
DASHBOARD_BASE_DIR="${CX_DASHBOARD_HOME:-$HOME_DIR/.cx/dashboard}"
REGISTRY_PATH="${CX_DASHBOARD_REGISTRY_PATH:-$DASHBOARD_BASE_DIR/registry.json}"
RUNTIME_PATH="${CX_DASHBOARD_RUNTIME_PATH:-$DASHBOARD_BASE_DIR/runtime.json}"
SERVICE_HOST="${CX_DASHBOARD_HOST:-127.0.0.1}"
BACKEND_BASE_PORT="${CX_DASHBOARD_BACKEND_BASE_PORT:-43120}"
FRONTEND_BASE_PORT="${CX_DASHBOARD_FRONTEND_BASE_PORT:-43130}"

runtime_json=$(
  cd "$REPO_ROOT/apps/dashboard-service" && \
    node --import tsx src/runtime.ts ensure \
      --registry-path "$REGISTRY_PATH" \
      --runtime-path "$RUNTIME_PATH" \
      --service-host "$SERVICE_HOST" \
      --backend-base-port "$BACKEND_BASE_PORT" \
      --frontend-base-port "$FRONTEND_BASE_PORT"
)

printf 'runtime_path=%s\n' "$RUNTIME_PATH"
printf 'service_status=%s\n' "$(jq -r '.service_status' <<< "$runtime_json")"
printf 'backend_port=%s\n' "$(jq -r '.backend_port' <<< "$runtime_json")"
printf 'frontend_port=%s\n' "$(jq -r '.frontend_port' <<< "$runtime_json")"
printf 'api_base_url=%s\n' "$(jq -r '.api_base_url' <<< "$runtime_json")"
printf 'frontend_url=%s\n' "$(jq -r '.frontend_url' <<< "$runtime_json")"
