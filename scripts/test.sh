#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT_DIR/scripts/run-pwsh.sh" "$ROOT_DIR/tests/Validate-Content.Tests.ps1"
"$ROOT_DIR/scripts/run-pwsh.sh" "$ROOT_DIR/tests/Render-Experience.Tests.ps1"
"$ROOT_DIR/scripts/run-pwsh.sh" "$ROOT_DIR/tests/Build-Preview.Tests.ps1"