#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

HOME_DIR="${HOME:-$(cd ~ && pwd)}"
DASHBOARD_BASE_DIR="${CX_DASHBOARD_HOME:-$HOME_DIR/.cx/dashboard}"
REGISTRY_PATH="${CX_DASHBOARD_REGISTRY_PATH:-$DASHBOARD_BASE_DIR/registry.json}"
RUNTIME_PATH="${CX_DASHBOARD_RUNTIME_PATH:-$DASHBOARD_BASE_DIR/runtime.json}"

runtime_json=$(
  cd "$REPO_ROOT/apps/dashboard-service" && \
    node --import tsx src/runtime.ts read \
      --registry-path "$REGISTRY_PATH" \
      --runtime-path "$RUNTIME_PATH"
)

frontend_url=$(jq -r '.frontend_url // empty' <<< "$runtime_json")

if [[ -z "$frontend_url" ]]; then
  echo "[cx-dashboard-open] dashboard frontend_url is empty" >&2
  exit 1
fi

if command -v open >/dev/null 2>&1; then
  open "$frontend_url"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$frontend_url"
else
  printf '%s\n' "$frontend_url"
fi
