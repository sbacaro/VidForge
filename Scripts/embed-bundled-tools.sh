#!/usr/bin/env bash
# Embeds vendored engines into VidForge.app/Contents/Helpers.
# Used as an Xcode Run Script build phase — not for end users.
set -euo pipefail

SOURCE="${SRCROOT}/VidForge/BundledTools"
HELPERS="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Helpers"

for tool in yt-dlp ffmpeg ffprobe; do
  if [[ ! -f "${SOURCE}/${tool}" ]]; then
    echo "error: Missing bundled tool: ${SOURCE}/${tool}"
    echo "error: Run Scripts/vendor-tools.sh before building."
    exit 1
  fi
done

mkdir -p "${HELPERS}"

for tool in yt-dlp ffmpeg ffprobe; do
  cp -f "${SOURCE}/${tool}" "${HELPERS}/${tool}"
  chmod +x "${HELPERS}/${tool}"
  xattr -cr "${HELPERS}/${tool}" 2>/dev/null || true
done

# Sign nested helpers so Hardened Runtime allows spawning them.
sign_helper() {
  local path="$1"
  if [[ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" && "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]]; then
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --timestamp=none --options runtime "${path}"
  else
    codesign --force --sign - --timestamp=none "${path}"
  fi
}

sign_helper "${HELPERS}/yt-dlp"
sign_helper "${HELPERS}/ffmpeg"
sign_helper "${HELPERS}/ffprobe"

echo "Embedded bundled tools → ${HELPERS}"
ls -lh "${HELPERS}/yt-dlp" "${HELPERS}/ffmpeg" "${HELPERS}/ffprobe"
