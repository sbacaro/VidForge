#!/usr/bin/env bash
# Maintainer utility: refresh engines that get copied into VidForge.app at build time.
# End users never run this — the .app already contains the binaries.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/VidForge/BundledTools"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DEST"
ARCH="$(uname -m)"

echo "┌──────────────────────────────────────┐"
echo "│  VidForge — vendor bundled engines   │"
echo "└──────────────────────────────────────┘"
echo "Architecture: $ARCH"
echo "Destination:  $DEST"
echo ""

echo "→ yt-dlp (universal macOS binary)"
curl -fsSL -L -o "$DEST/yt-dlp" \
  "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
chmod +x "$DEST/yt-dlp"

if [[ "$ARCH" == "arm64" ]]; then
  echo "→ ffmpeg (Apple Silicon static)"
  curl -fsSL -L -o "$TMP/ffmpeg.zip" "https://www.osxexperts.net/ffmpeg7arm.zip"
  unzip -qo "$TMP/ffmpeg.zip" -d "$TMP/ff"
  cp "$TMP/ff/ffmpeg" "$DEST/ffmpeg"

  echo "→ ffprobe (Apple Silicon static)"
  curl -fsSL -L -o "$TMP/ffprobe.zip" "https://www.osxexperts.net/ffprobe7arm.zip"
  unzip -qo "$TMP/ffprobe.zip" -d "$TMP/fp"
  cp "$TMP/fp/ffprobe" "$DEST/ffprobe"
else
  echo "→ ffmpeg / ffprobe (Intel via evermeet.cx)"
  curl -fsSL -L -o "$TMP/ffmpeg.zip" "https://evermeet.cx/ffmpeg/getrelease/zip"
  curl -fsSL -L -o "$TMP/ffprobe.zip" "https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip"
  unzip -qo "$TMP/ffmpeg.zip" -d "$TMP/ff"
  unzip -qo "$TMP/ffprobe.zip" -d "$TMP/fp"
  cp "$TMP/ff/ffmpeg" "$DEST/ffmpeg"
  cp "$TMP/fp/ffprobe" "$DEST/ffprobe"
fi

chmod +x "$DEST/ffmpeg" "$DEST/ffprobe"
xattr -cr "$DEST/yt-dlp" "$DEST/ffmpeg" "$DEST/ffprobe" 2>/dev/null || true

cat > "$DEST/README.txt" << 'EOF'
Bundled engines copied into VidForge.app/Contents/Helpers at build time.
Runtime never downloads or invokes Homebrew tools.
Refresh with: Scripts/vendor-tools.sh
EOF

echo ""
echo "Versions:"
"$DEST/yt-dlp" --version
"$DEST/ffmpeg" -version | head -n 1
"$DEST/ffprobe" -version | head -n 1
ls -lh "$DEST/yt-dlp" "$DEST/ffmpeg" "$DEST/ffprobe"
echo ""
echo "Done. Build the Xcode project to embed them in the .app."
