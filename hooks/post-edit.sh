#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/cx-runtime.sh"

if ! cx_has_runtime || ! cx_require_jq; then
  exit 0
fi

AUTO_FORMAT_ENABLED=$(jq -r '.auto_format.enabled // false' "$(cx_config_file)" 2>/dev/null)
if [[ "$AUTO_FORMAT_ENABLED" != "true" ]]; then
  exit 0
fi

PAYLOAD=""
if [[ ! -t 0 ]]; then
  PAYLOAD=$(cat)
fi

EDITED_FILE="${EDITED_FILE:-}"
if [[ -z "$EDITED_FILE" && -n "$PAYLOAD" ]]; then
  EDITED_FILE=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
fi

if [[ -z "$EDITED_FILE" || ! -f "$EDITED_FILE" ]]; then
  exit 0
fi

FILE_EXT="${EDITED_FILE##*.}"

case "$FILE_EXT" in
  js|ts|jsx|tsx|json|css|md|yml|yaml)
    if command -v prettier >/dev/null 2>&1; then
      prettier --write "$EDITED_FILE" >/dev/null 2>&1 &
    fi
    ;;
  py)
    if command -v black >/dev/null 2>&1; then
      black "$EDITED_FILE" >/dev/null 2>&1 &
    fi
    ;;
  go)
    if command -v gofmt >/dev/null 2>&1; then
      gofmt -w "$EDITED_FILE" >/dev/null 2>&1 &
    fi
    ;;
  rs)
    if command -v rustfmt >/dev/null 2>&1; then
      rustfmt "$EDITED_FILE" >/dev/null 2>&1 &
    fi
    ;;
esac
