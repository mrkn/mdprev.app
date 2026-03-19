#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-dist}"
ABS_OUT_DIR="${PROJECT_ROOT}/${OUT_DIR}"
PROJECT_PATH="${PROJECT_ROOT}/mdprev.xcodeproj"
SCHEME="mdprev"

mkdir -p "${ABS_OUT_DIR}"
rm -rf "${ABS_OUT_DIR}/mdprev.app" "${ABS_OUT_DIR}/mdprev.app.dSYM"

pushd "${PROJECT_ROOT}" >/dev/null
ruby scripts/generate_xcodeproj.rb

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination "platform=macOS" \
  CONFIGURATION_BUILD_DIR="${ABS_OUT_DIR}" \
  build

if [[ ! -d "${ABS_OUT_DIR}/mdprev.app" ]]; then
  echo "Release app bundle was not generated at ${ABS_OUT_DIR}/mdprev.app" >&2
  exit 1
fi

echo "Built ${ABS_OUT_DIR}/mdprev.app"
popd >/dev/null
