#!/usr/bin/env bash
set -euo pipefail

APP_NAME="mdprev"
BUNDLE_ID="io.github.mrkn.mdprev"
APP_VERSION="0.1.0"
BUILD_NUMBER="1"
MIN_SYSTEM_VERSION="13.0"
OUT_DIR="${1:-dist}"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE_PATH="${PROJECT_ROOT}/${OUT_DIR}/${APP_NAME}.app"
CONTENTS_PATH="${APP_BUNDLE_PATH}/Contents"
MACOS_PATH="${CONTENTS_PATH}/MacOS"
RESOURCES_PATH="${CONTENTS_PATH}/Resources"

ICON_SOURCE_ICNS="${PROJECT_ROOT}/assets/app-icon/mdprev.icns"
ICON_SOURCE_ICONSET="${PROJECT_ROOT}/assets/app-icon/AppIcon.iconset"
ICON_OUTPUT_BASENAME="AppIcon"
ICON_OUTPUT_ICNS="${RESOURCES_PATH}/${ICON_OUTPUT_BASENAME}.icns"

mkdir -p /tmp/swift-module-cache

pushd "${PROJECT_ROOT}" >/dev/null
SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swift-module-cache \
swift build -c release --disable-sandbox

BIN_PATH="$(find .build -type f -path "*/release/${APP_NAME}" | head -n 1)"
if [[ -z "${BIN_PATH}" ]]; then
  echo "Release binary not found for ${APP_NAME}" >&2
  exit 1
fi

rm -rf "${APP_BUNDLE_PATH}"
mkdir -p "${MACOS_PATH}" "${RESOURCES_PATH}"
cp "${BIN_PATH}" "${MACOS_PATH}/${APP_NAME}"
chmod +x "${MACOS_PATH}/${APP_NAME}"

while IFS= read -r -d '' bundle_path; do
  cp -R "${bundle_path}" "${RESOURCES_PATH}/"
done < <(find .build -type d -path "*/release/${APP_NAME}_*.bundle" -print0)

HAS_ICON="false"
if [[ -f "${ICON_SOURCE_ICNS}" ]]; then
  cp "${ICON_SOURCE_ICNS}" "${ICON_OUTPUT_ICNS}"
  HAS_ICON="true"
elif [[ -d "${ICON_SOURCE_ICONSET}" ]] && command -v iconutil >/dev/null 2>&1; then
  if iconutil -c icns "${ICON_SOURCE_ICONSET}" -o "${ICON_OUTPUT_ICNS}" >/dev/null 2>&1; then
    HAS_ICON="true"
  else
    echo "Warning: iconutil failed; app bundle will be created without .icns icon." >&2
  fi
fi

INFO_PLIST_PATH="${CONTENTS_PATH}/Info.plist"
if [[ "${HAS_ICON}" == "true" ]]; then
  cat > "${INFO_PLIST_PATH}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>${ICON_OUTPUT_BASENAME}</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Markdown Document</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>net.daringfireball.markdown</string>
      </array>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>md</string>
        <string>markdown</string>
      </array>
      <key>CFBundleTypeMIMETypes</key>
      <array>
        <string>text/markdown</string>
      </array>
    </dict>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_SYSTEM_VERSION}</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST
else
  cat > "${INFO_PLIST_PATH}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Markdown Document</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>net.daringfireball.markdown</string>
      </array>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>md</string>
        <string>markdown</string>
      </array>
      <key>CFBundleTypeMIMETypes</key>
      <array>
        <string>text/markdown</string>
      </array>
    </dict>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_SYSTEM_VERSION}</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST
fi

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "${INFO_PLIST_PATH}" >/dev/null
fi

if command -v codesign >/dev/null 2>&1; then
  if ! codesign --force --deep --sign - "${APP_BUNDLE_PATH}" >/dev/null 2>&1; then
    echo "Warning: ad-hoc codesign failed; continuing with unsigned app." >&2
  fi
fi

popd >/dev/null

echo "Created release app: ${APP_BUNDLE_PATH}"
