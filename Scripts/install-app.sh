#!/usr/bin/env bash
# Build and install VidForge.app into ~/Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "${ROOT}/Scripts/bundle-app.sh"

APP_SRC="${ROOT}/dist/VidForge.app"
APP_DST="${HOME}/Applications/VidForge.app"
mkdir -p "${HOME}/Applications"
rm -rf "${APP_DST}"
cp -R "${APP_SRC}" "${APP_DST}"
xattr -cr "${APP_DST}" 2>/dev/null || true

echo ""
echo "Installed → ${APP_DST}"
echo "Open with: open \"${APP_DST}\""
open "${APP_DST}"
