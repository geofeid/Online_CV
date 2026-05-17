#!/usr/bin/env bash
set -euo pipefail

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$@"
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$@"
else
  echo "Neither pwsh nor powershell.exe was found in PATH." >&2
  exit 1
fi