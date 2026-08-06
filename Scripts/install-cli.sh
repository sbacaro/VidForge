#!/usr/bin/env bash
# Install VidForge CLI into ~/.local (no Xcode, no Homebrew).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${HOME}/.local"
SHARE="${PREFIX}/share/vidforge"
BIN_DIR="${SHARE}/bin"
LINK="${PREFIX}/bin/vidforge"
TOOLS="${ROOT}/VidForge/BundledTools"

echo "┌──────────────────────────────────┐"
echo "│  VidForge CLI installer          │"
echo "└──────────────────────────────────┘"
echo "Prefix: ${PREFIX}"
echo ""

for tool in yt-dlp ffmpeg ffprobe; do
  if [[ ! -f "${TOOLS}/${tool}" ]]; then
    echo "error: missing ${TOOLS}/${tool}"
    echo "Run: ${ROOT}/Scripts/vendor-tools.sh"
    exit 1
  fi
done

echo "→ Building vidforge (swift package)…"
cd "${ROOT}"
swift build -c release --product vidforge

BUILT="$(swift build -c release --product vidforge --show-bin-path)/vidforge"
if [[ ! -x "${BUILT}" ]]; then
  echo "error: build output not found at ${BUILT}"
  exit 1
fi

echo "→ Installing into ${SHARE}…"
mkdir -p "${BIN_DIR}" "${PREFIX}/bin"
cp -f "${BUILT}" "${BIN_DIR}/vidforge"
cp -f "${TOOLS}/yt-dlp" "${TOOLS}/ffmpeg" "${TOOLS}/ffprobe" "${BIN_DIR}/"
chmod +x "${BIN_DIR}/vidforge" "${BIN_DIR}/yt-dlp" "${BIN_DIR}/ffmpeg" "${BIN_DIR}/ffprobe"
xattr -cr "${BIN_DIR}/vidforge" "${BIN_DIR}/yt-dlp" "${BIN_DIR}/ffmpeg" "${BIN_DIR}/ffprobe" 2>/dev/null || true

# Keep a tiny launcher so VIDFORGE_HOME is always set.
cat > "${LINK}" << EOF
#!/usr/bin/env bash
export VIDFORGE_HOME="${BIN_DIR}"
exec "${BIN_DIR}/vidforge" "\$@"
EOF
chmod +x "${LINK}"

# Ensure ~/.local/bin is on PATH for this shell and future zsh/bash sessions.
ensure_path_line='export PATH="$HOME/.local/bin:$PATH"'
for rc in "${HOME}/.zshrc" "${HOME}/.zprofile" "${HOME}/.bashrc" "${HOME}/.bash_profile"; do
  if [[ -f "${rc}" ]] || [[ "${rc}" == "${HOME}/.zshrc" ]]; then
    touch "${rc}"
    if ! grep -Fq '.local/bin' "${rc}" 2>/dev/null; then
      printf '\n# VidForge\n%s\n' "${ensure_path_line}" >> "${rc}"
      echo "→ Added PATH to ${rc}"
    fi
  fi
done

echo ""
echo "Installed: ${LINK}"
echo "Engines:   ${BIN_DIR}/{yt-dlp,ffmpeg,ffprobe}"
echo ""
echo "Reload your shell (or run):"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
echo "Then:"
echo "  vidforge --help"
echo "  vidforge \"https://www.youtube.com/watch?v=…\""
