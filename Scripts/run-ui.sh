#!/usr/bin/env bash
# Launch VidForge UI by executing the binary directly (bypasses Launch Services mix-ups).
set -euo pipefail
APP="${HOME}/Applications/VidForge.app"
BIN="${APP}/Contents/MacOS/VidForge"
if [[ ! -x "${BIN}" ]]; then
  echo "VidForge UI not installed. Run:" >&2
  echo "  ~/Projects/VidForge/Scripts/install-app.sh" >&2
  exit 1
fi
xattr -cr "${APP}" 2>/dev/null || true
# Make sure Dock/mission control show a clear name.
export __CFBundleIdentifier=com.samuelbacaro.vidforge.ui
exec "${BIN}"
