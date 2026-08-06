#!/usr/bin/env bash
# Build VidForge.app with bundled yt-dlp / ffmpeg / ffprobe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${ROOT}/dist"
APP="${DIST}/VidForge.app"
MACOS="${APP}/Contents/MacOS"
RES="${APP}/Contents/Resources/engines"
BIN_NAME="VidForge"

echo "┌──────────────────────────────────┐"
echo "│  VidForge — build macOS app      │"
echo "└──────────────────────────────────┘"

if [[ ! -x "${ROOT}/vendor/yt-dlp" || ! -x "${ROOT}/vendor/ffmpeg" || ! -x "${ROOT}/vendor/ffprobe" ]]; then
  echo "Vendoring engines…"
  bash "${ROOT}/Scripts/vendor-tools.sh"
fi

cd "${ROOT}"
swift build -c release --product VidForge
BUILT="$(swift build -c release --product VidForge --show-bin-path)/${BIN_NAME}"

rm -rf "${APP}"
mkdir -p "${MACOS}" "${RES}" "${APP}/Contents/Resources"
cp -f "${BUILT}" "${MACOS}/${BIN_NAME}"
cp -f "${ROOT}/vendor/yt-dlp" "${ROOT}/vendor/ffmpeg" "${ROOT}/vendor/ffprobe" "${RES}/"
chmod +x "${MACOS}/${BIN_NAME}" "${RES}/yt-dlp" "${RES}/ffmpeg" "${RES}/ffprobe"
xattr -cr "${APP}" 2>/dev/null || true

# App icon (ember ingot on iron)
ICONSET="${DIST}/VidForge.iconset"
BASE="${DIST}/icon-base.png"
rm -rf "${ICONSET}"
mkdir -p "${ICONSET}"
python3 - "$BASE" <<'PY'
import math, struct, zlib, sys
from pathlib import Path
size = 1024
path = Path(sys.argv[1])
rows = []
for y in range(size):
    row = bytearray([0])
    for x in range(size):
        cx, cy = size / 2, size * 0.58
        d = math.hypot(x - cx, y - cy) / (size * 0.22)
        if d < 1:
            t = 1 - d
            r = int(14 + (232 - 14) * t)
            g = int(13 + (121 - 13) * t)
            b = int(12 + (43 - 12) * t)
        elif abs(y - size * 0.28) < size * 0.035 and abs(x - cx) < size * 0.18:
            r, g, b = 246, 195, 93
        else:
            v = min(1.0, math.hypot(x - size / 2, y - size / 2) / (size * 0.75))
            shade = int(18 + (30 - 18) * (1 - v))
            r, g, b = shade + 4, shade, max(0, shade - 2)
        row += bytes((max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))))
    rows.append(bytes(row))
raw = b"".join(rows)
ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

path.write_bytes(
    b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
)
PY

if command -v sips >/dev/null 2>&1; then
  for dim in 16 32 128 256 512; do
    sips -z "$dim" "$dim" "${BASE}" --out "${ICONSET}/icon_${dim}x${dim}.png" >/dev/null
    sips -z $((dim * 2)) $((dim * 2)) "${BASE}" --out "${ICONSET}/icon_${dim}x${dim}@2x.png" >/dev/null
  done
  if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "${ICONSET}" -o "${APP}/Contents/Resources/AppIcon.icns" || true
  fi
fi

cat > "${APP}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${BIN_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.sbacaro.VidForge</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>VidForge</string>
  <key>CFBundleDisplayName</key>
  <string>VidForge</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>2.0.0</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © VidForge</string>
</dict>
</plist>
EOF

echo ""
echo "Built: ${APP}"
