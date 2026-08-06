#!/usr/bin/env bash
# Build the SwiftUI UI and install VidForge.app — no Xcode required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${ROOT}/VidForge/BundledTools"
APP_DIR="${HOME}/Applications"
APP="${APP_DIR}/VidForge.app"
CONTENTS="${APP}/Contents"
MACOS="${CONTENTS}/MacOS"
HELPERS="${CONTENTS}/Helpers"
RESOURCES="${CONTENTS}/Resources"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "┌──────────────────────────────────┐"
echo "│  VidForge UI installer           │"
echo "└──────────────────────────────────┘"

for tool in yt-dlp ffmpeg ffprobe; do
  if [[ ! -f "${TOOLS}/${tool}" ]]; then
    echo "error: missing ${TOOLS}/${tool}"
    echo "Run: ${ROOT}/Scripts/vendor-tools.sh"
    exit 1
  fi
done

echo "→ Building SwiftUI app (swift package)…"
cd "${ROOT}"
swift build -c release --product VidForgeApp
BUILT="$(swift build -c release --product VidForgeApp --show-bin-path)/VidForgeApp"
if [[ ! -x "${BUILT}" ]]; then
  echo "error: build output not found: ${BUILT}"
  exit 1
fi

echo "→ Assembling ${APP}…"
rm -rf "${APP}"
mkdir -p "${MACOS}" "${HELPERS}" "${RESOURCES}"

cp -f "${BUILT}" "${MACOS}/VidForge"
chmod +x "${MACOS}/VidForge"
cp -f "${TOOLS}/yt-dlp" "${TOOLS}/ffmpeg" "${TOOLS}/ffprobe" "${HELPERS}/"
chmod +x "${HELPERS}/yt-dlp" "${HELPERS}/ffmpeg" "${HELPERS}/ffprobe"
xattr -cr "${APP}" 2>/dev/null || true

printf 'APPL????' > "${CONTENTS}/PkgInfo"

cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>VidForge</string>
	<key>CFBundleIdentifier</key>
	<string>dev.samuelbacaro.vidforge</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>VidForge</string>
	<key>CFBundleDisplayName</key>
	<string>VidForge Video</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.video</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>LSUIElement</key>
	<false/>
</dict>
</plist>
PLIST

# Sign nested helpers first, then the app (adhoc).
codesign --force --sign - --timestamp=none "${HELPERS}/yt-dlp" 2>/dev/null || true
codesign --force --sign - --timestamp=none "${HELPERS}/ffmpeg" 2>/dev/null || true
codesign --force --sign - --timestamp=none "${HELPERS}/ffprobe" 2>/dev/null || true
codesign --force --sign - --timestamp=none "${MACOS}/VidForge" 2>/dev/null || true
codesign --force --deep --sign - "${APP}" 2>/dev/null || true
xattr -cr "${APP}" 2>/dev/null || true

"${LSREGISTER}" -f "${APP}" 2>/dev/null || true

# CLI launcher (uses Finder/`open`, not Cursor's process tree)
mkdir -p "${HOME}/.local/bin"
cat > "${HOME}/.local/bin/vidforge-ui" << EOF
#!/usr/bin/env bash
APP="${APP}"
xattr -cr "\${APP}" 2>/dev/null || true
# Prefer launching through LaunchServices with absolute path.
/usr/bin/open -n "\${APP}"
EOF
chmod +x "${HOME}/.local/bin/vidforge-ui"

# Desktop double-click launcher (opens via Finder context)
DESKTOP="${HOME}/Desktop/VidForge Video.command"
cat > "${DESKTOP}" << EOF
#!/bin/bash
# Double-click this file to open VidForge Video (NOT SpectraLayers / Steinberg).
xattr -cr "${APP}" 2>/dev/null || true
/usr/bin/open -n "${APP}"
EOF
chmod +x "${DESKTOP}"
xattr -cr "${DESKTOP}" 2>/dev/null || true

echo ""
echo "Installed: ${APP}"
echo "Desktop:   ~/Desktop/VidForge Video.command"
echo "CLI:       vidforge-ui"
echo ""
echo "IMPORTANT: That Steinberg Activation window is SpectraLayers / WaveLab,"
echo "not VidForge. Open ONLY:"
echo "  ${APP}"
echo "or double-click: VidForge Video.command on your Desktop."
echo ""
echo "Opening VidForge via Finder…"
/usr/bin/open -n "${APP}" || true
