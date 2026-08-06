#!/usr/bin/env bash
# Install the local companion API used by the GitHub Pages UI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${HOME}/.local"
SHARE="${PREFIX}/share/vidforge"
BIN_DIR="${SHARE}/bin"
TOOLS="${ROOT}/vendor"
PAGES_URL="https://sbacaro.github.io/VidForge/"

echo "┌──────────────────────────────────┐"
echo "│  VidForge companion installer    │"
echo "└──────────────────────────────────┘"

for tool in yt-dlp ffmpeg ffprobe; do
  [[ -f "${TOOLS}/${tool}" ]] || { echo "missing ${tool} — run Scripts/vendor-tools.sh"; exit 1; }
done

cd "${ROOT}"
swift build -c release --product vidforge-ui-server
BUILT="$(swift build -c release --product vidforge-ui-server --show-bin-path)/vidforge-ui-server"

mkdir -p "${BIN_DIR}" "${PREFIX}/bin"
cp -f "${BUILT}" "${BIN_DIR}/vidforge-ui-server"
cp -f "${TOOLS}/yt-dlp" "${TOOLS}/ffmpeg" "${TOOLS}/ffprobe" "${BIN_DIR}/"
chmod +x "${BIN_DIR}/vidforge-ui-server" "${BIN_DIR}/yt-dlp" "${BIN_DIR}/ffmpeg" "${BIN_DIR}/ffprobe"
xattr -cr "${BIN_DIR}/vidforge-ui-server" "${BIN_DIR}/yt-dlp" "${BIN_DIR}/ffmpeg" "${BIN_DIR}/ffprobe" 2>/dev/null || true

cat > "${PREFIX}/bin/vidforge-ui" << EOF
#!/usr/bin/env bash
export VIDFORGE_HOME="${BIN_DIR}"
exec "${BIN_DIR}/vidforge-ui-server" "\$@"
EOF
chmod +x "${PREFIX}/bin/vidforge-ui"

cat > "${HOME}/Desktop/VidForge Video.command" << EOF
#!/bin/bash
export PATH="\$HOME/.local/bin:\$PATH"
export VIDFORGE_HOME="${BIN_DIR}"
# Start companion, then open the GitHub Pages UI.
"${BIN_DIR}/vidforge-ui-server" &
sleep 1
open "${PAGES_URL}"
wait
EOF
chmod +x "${HOME}/Desktop/VidForge Video.command"
xattr -cr "${HOME}/Desktop/VidForge Video.command" 2>/dev/null || true

echo ""
echo "Installed. Start companion:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "  vidforge-ui"
echo ""
echo "Then use: ${PAGES_URL}"
