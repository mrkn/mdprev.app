#!/usr/bin/env bash
set -euo pipefail

SOURCE_PNG="${1:-assets/icon-candidates/icon-candidate-03-monogram.png}"
OUTPUT_DIR="${2:-assets/app-icon}"
ICONSET_DIR="${OUTPUT_DIR}/AppIcon.iconset"
ICNS_PATH="${OUTPUT_DIR}/mdprev.icns"

if [[ ! -f "${SOURCE_PNG}" ]]; then
  echo "Source icon not found: ${SOURCE_PNG}" >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "sips is required but not found." >&2
  exit 1
fi

if ! command -v iconutil >/dev/null 2>&1; then
  echo "iconutil is required but not found." >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

render_icon() {
  local size="$1"
  local name="$2"
  sips -z "${size}" "${size}" "${SOURCE_PNG}" --out "${ICONSET_DIR}/${name}" >/dev/null
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

cp "${SOURCE_PNG}" "${OUTPUT_DIR}/selected-source.png"

echo "Generated iconset: ${ICONSET_DIR}"
if iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_PATH}" >/dev/null 2>&1; then
  echo "Generated icns: ${ICNS_PATH}"
else
  echo "Warning: iconutil failed to convert iconset to icns in this environment." >&2
fi
