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
BACKEND_PID_PATH="$DASHBOARD_BASE_DIR/backend.pid"
FRONTEND_PID_PATH="$DASHBOARD_BASE_DIR/frontend.pid"
BACKEND_LOG_PATH="$DASHBOARD_BASE_DIR/backend.log"
FRONTEND_LOG_PATH="$DASHBOARD_BASE_DIR/frontend.log"

read_runtime_json() {
  (
    cd "$REPO_ROOT/apps/dashboard-service" && \
      node --import tsx src/runtime.ts read \
        --registry-path "$REGISTRY_PATH" \
        --runtime-path "$RUNTIME_PATH"
  )
}

ensure_runtime_json() {
  (
    cd "$REPO_ROOT/apps/dashboard-service" && \
      node --import tsx src/runtime.ts ensure \
        --registry-path "$REGISTRY_PATH" \
        --runtime-path "$RUNTIME_PATH" \
        --service-host "$SERVICE_HOST" \
        --backend-base-port "$BACKEND_BASE_PORT" \
        --frontend-base-port "$FRONTEND_BASE_PORT"
  )
}

probe_url() {
  local url="$1"
  [[ -n "$url" ]] || return 1
  curl -fsS -m 1 "$url" >/dev/null 2>&1
}

wait_for_url() {
  local url="$1"
  local attempts="${2:-40}"
  local delay="${3:-0.25}"
  local index=0

  while (( index < attempts )); do
    if probe_url "$url"; then
      return 0
    fi
    sleep "$delay"
    index=$((index + 1))
  done

  return 1
}

read_pid() {
  local pid_path="$1"
  if [[ -f "$pid_path" ]]; then
    tr -d '[:space:]' < "$pid_path"
  fi
}

pid_running() {
  local pid_path="$1"
  local pid
  pid=$(read_pid "$pid_path")
  [[ -n "${pid:-}" ]] && kill -0 "$pid" >/dev/null 2>&1
}

clear_stale_pid() {
  local pid_path="$1"
  if pid_running "$pid_path"; then
    kill "$(read_pid "$pid_path")" >/dev/null 2>&1 || true
    sleep 0.2
  fi
  rm -f "$pid_path"
}

persist_runtime_status() {
  local runtime_json="$1"
  local service_status="$2"
  local last_error="$3"
  local started_now="$4"
  local backend_pid_json="$5"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq \
    --arg service_status "$service_status" \
    --arg last_error "$last_error" \
    --arg started_now "$started_now" \
    --arg timestamp "$timestamp" \
    --argjson pid "$backend_pid_json" \
    '
      .service_status = $service_status
      | .last_checked_at = $timestamp
      | .last_error = (if $last_error == "" then null else $last_error end)
      | .pid = $pid
      | if $started_now == "true" then .last_started_at = $timestamp else . end
    ' <<< "$runtime_json" > "$RUNTIME_PATH"
}

mkdir -p "$DASHBOARD_BASE_DIR"

runtime_json=$(read_runtime_json)
existing_api_base_url=$(jq -r '.api_base_url // empty' <<< "$runtime_json")
existing_frontend_url=$(jq -r '.frontend_url // empty' <<< "$runtime_json")

if probe_url "$existing_api_base_url/health" && probe_url "$existing_frontend_url"; then
  printf 'runtime_path=%s\n' "$RUNTIME_PATH"
  printf 'service_status=%s\n' "$(jq -r '.service_status' <<< "$runtime_json")"
  printf 'backend_port=%s\n' "$(jq -r '.backend_port' <<< "$runtime_json")"
  printf 'frontend_port=%s\n' "$(jq -r '.frontend_port' <<< "$runtime_json")"
  printf 'api_base_url=%s\n' "$existing_api_base_url"
  printf 'frontend_url=%s\n' "$existing_frontend_url"
  exit 0
fi

existing_backend_port=$(jq -r '.backend_port // empty' <<< "$runtime_json")
existing_frontend_port=$(jq -r '.frontend_port // empty' <<< "$runtime_json")

if [[ -n "$existing_backend_port" ]]; then
  BACKEND_BASE_PORT="$existing_backend_port"
fi
if [[ -n "$existing_frontend_port" ]]; then
  FRONTEND_BASE_PORT="$existing_frontend_port"
fi

runtime_json=$(ensure_runtime_json)
backend_port=$(jq -r '.backend_port' <<< "$runtime_json")
frontend_port=$(jq -r '.frontend_port' <<< "$runtime_json")
api_base_url=$(jq -r '.api_base_url' <<< "$runtime_json")
frontend_url=$(jq -r '.frontend_url' <<< "$runtime_json")

started_now=false
last_error=""

if ! probe_url "$api_base_url/health"; then
  clear_stale_pid "$BACKEND_PID_PATH"
  (
    cd "$REPO_ROOT/apps/dashboard-service" && \
      CX_DASHBOARD_REGISTRY_PATH="$REGISTRY_PATH" \
      CX_DASHBOARD_PORT="$backend_port" \
      nohup npm start > "$BACKEND_LOG_PATH" 2>&1 &
    echo $! > "$BACKEND_PID_PATH"
  )
  started_now=true
fi

if ! wait_for_url "$api_base_url/health" 80 0.25; then
  last_error="dashboard backend failed to start"
fi

if [[ -z "$last_error" ]] && ! probe_url "$frontend_url"; then
  clear_stale_pid "$FRONTEND_PID_PATH"
  (
    cd "$REPO_ROOT/apps/dashboard-web" && \
      VITE_CX_DASHBOARD_API_BASE_URL="$api_base_url" \
      nohup npm run dev -- --host "$SERVICE_HOST" --port "$frontend_port" > "$FRONTEND_LOG_PATH" 2>&1 &
    echo $! > "$FRONTEND_PID_PATH"
  )
  started_now=true
fi

if [[ -z "$last_error" ]] && ! wait_for_url "$frontend_url" 120 0.25; then
  last_error="dashboard frontend failed to start"
fi

if [[ -n "$last_error" ]]; then
  service_status="degraded"
else
  service_status="running"
fi

backend_pid_json=null
if pid_running "$BACKEND_PID_PATH"; then
  backend_pid_json=$(read_pid "$BACKEND_PID_PATH")
fi

persist_runtime_status "$runtime_json" "$service_status" "$last_error" "$started_now" "$backend_pid_json"
runtime_json=$(cat "$RUNTIME_PATH")

printf 'runtime_path=%s\n' "$RUNTIME_PATH"
printf 'service_status=%s\n' "$(jq -r '.service_status' <<< "$runtime_json")"
printf 'backend_port=%s\n' "$(jq -r '.backend_port' <<< "$runtime_json")"
printf 'frontend_port=%s\n' "$(jq -r '.frontend_port' <<< "$runtime_json")"
printf 'api_base_url=%s\n' "$(jq -r '.api_base_url' <<< "$runtime_json")"
printf 'frontend_url=%s\n' "$(jq -r '.frontend_url' <<< "$runtime_json")"
