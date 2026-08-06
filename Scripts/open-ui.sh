#!/usr/bin/env bash
# Always open the real VidForge UI (never a browser / wrong app).
set -euo pipefail
APP="${HOME}/Applications/VidForge.app"
if [[ ! -d "${APP}" ]]; then
  echo "VidForge.app not found. Run: $(dirname "$0")/install-app.sh" >&2
  exit 1
fi
# Clear quarantine so Gatekeeper doesn't block / weird-redirect.
xattr -cr "${APP}" 2>/dev/null || true
# Force this exact bundle path.
open -n "${APP}" --args "$@"
