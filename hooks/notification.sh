#!/bin/bash

# Hook: Notification
# Purpose: Send desktop notification to user
# Supports: macOS (osascript), Linux (notify-send), WSL/Windows (powershell.exe)
# Usage: notification.sh "Message text"

set -e

# Get message from argument, use default if not provided
MSG="${1:-CX 工作流任务已完成}"

# Detect OS and send appropriate notification
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  if command -v osascript &>/dev/null; then
    osascript -e "display notification \"$MSG\" with title \"cx-workflow\"" &>/dev/null || true
  fi

elif [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -n "${WSL_INTEROP:-}" ]]; then
  # WSL (Windows Subsystem for Linux)
  if command -v powershell.exe &>/dev/null; then
    powershell.exe -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('$MSG','cx-workflow')" &>/dev/null &
  elif command -v notify-send &>/dev/null; then
    # Fallback to notify-send on WSL with notification server
    notify-send "cx-workflow" "$MSG" &>/dev/null || true
  fi

elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  # Windows (Git Bash, MinGW)
  if command -v powershell.exe &>/dev/null; then
    powershell.exe -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('$MSG','cx-workflow')" &>/dev/null &
  fi

else
  # Linux
  if command -v notify-send &>/dev/null; then
    notify-send "cx-workflow" "$MSG" &>/dev/null || true
  fi
fi

exit 0
