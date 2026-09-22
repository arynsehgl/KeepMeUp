#!/bin/bash

# Builds a Universal Swift executable, assembles a macOS app bundle, ad-hoc signs it, and creates a DMG.
set -euo pipefail

# Resolves all paths relative to the repository so the script works locally and in GitHub Actions.
SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIRECTORY}/.." && pwd)"
OUTPUT_DIRECTORY="${1:-${PROJECT_ROOT}/dist}"
BUILD_DIRECTORY="${PROJECT_ROOT}/.build/package"
APP_DIRECTORY="${BUILD_DIRECTORY}/KeepMeUp.app"
CONTENTS_DIRECTORY="${APP_DIRECTORY}/Contents"
MACOS_DIRECTORY="${CONTENTS_DIRECTORY}/MacOS"
RESOURCES_DIRECTORY="${CONTENTS_DIRECTORY}/Resources"
DMG_STAGING_DIRECTORY="${BUILD_DIRECTORY}/dmg"
ICONSET_DIRECTORY="${BUILD_DIRECTORY}/AppIcon.iconset"
MASTER_ICON="${BUILD_DIRECTORY}/AppIcon-1024.png"
DMG_FILENAME="KeepMeUp-0.1.0.dmg"
DMG_PATH="${OUTPUT_DIRECTORY}/${DMG_FILENAME}"

# Keeps SwiftPM and compiler caches inside script-owned staging instead of writing to user directories.
SWIFT_BUILD_OPTIONS=(
    --package-path "${PROJECT_ROOT}"
    --configuration release
    --cache-path "${BUILD_DIRECTORY}/swiftpm-cache"
    --config-path "${BUILD_DIRECTORY}/swiftpm-config"
    --security-path "${BUILD_DIRECTORY}/swiftpm-security"
)

# Supports nested sandbox environments without weakening ordinary local or CI builds.
if [[ "${KEEPMEUP_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
    SWIFT_BUILD_OPTIONS+=(--disable-sandbox)
fi

# Removes only script-owned package staging so repeated builds cannot retain stale bundle contents.
rm -rf "${BUILD_DIRECTORY}"
mkdir -p "${MACOS_DIRECTORY}" "${RESOURCES_DIRECTORY}" "${DMG_STAGING_DIRECTORY}" "${ICONSET_DIRECTORY}" "${OUTPUT_DIRECTORY}"

# Builds each architecture independently and combines them into one Universal executable.
export CLANG_MODULE_CACHE_PATH="${BUILD_DIRECTORY}/clang-module-cache"
swift build "${SWIFT_BUILD_OPTIONS[@]}" --arch arm64 --scratch-path "${PROJECT_ROOT}/.build/arm64"
swift build "${SWIFT_BUILD_OPTIONS[@]}" --arch x86_64 --scratch-path "${PROJECT_ROOT}/.build/x86_64"
lipo -create \
    "${PROJECT_ROOT}/.build/arm64/arm64-apple-macosx/release/KeepMeUp" \
    "${PROJECT_ROOT}/.build/x86_64/x86_64-apple-macosx/release/KeepMeUp" \
    -output "${MACOS_DIRECTORY}/KeepMeUp"

# Converts the source SVG into every required icon size and packages the result as AppIcon.icns.
qlmanage -t -s 1024 -o "${BUILD_DIRECTORY}" "${PROJECT_ROOT}/Resources/AppIcon.svg" >/dev/null
mv "${BUILD_DIRECTORY}/AppIcon.svg.png" "${MASTER_ICON}"
for ICON_SIZE in 16 32 128 256 512; do
    sips -z "${ICON_SIZE}" "${ICON_SIZE}" "${MASTER_ICON}" --out "${ICONSET_DIRECTORY}/icon_${ICON_SIZE}x${ICON_SIZE}.png" >/dev/null
    DOUBLE_SIZE=$((ICON_SIZE * 2))
    sips -z "${DOUBLE_SIZE}" "${DOUBLE_SIZE}" "${MASTER_ICON}" --out "${ICONSET_DIRECTORY}/icon_${ICON_SIZE}x${ICON_SIZE}@2x.png" >/dev/null
done
iconutil -c icns "${ICONSET_DIRECTORY}" -o "${RESOURCES_DIRECTORY}/AppIcon.icns"

# Copies immutable bundle metadata and applies an ad-hoc signature for integrity without Developer ID trust.
cp "${PROJECT_ROOT}/Resources/Info.plist" "${CONTENTS_DIRECTORY}/Info.plist"
codesign --force --deep --sign - "${APP_DIRECTORY}"
codesign --verify --deep --strict "${APP_DIRECTORY}"

# Creates a familiar drag-to-Applications disk image and an adjacent SHA-256 checksum.
cp -R "${APP_DIRECTORY}" "${DMG_STAGING_DIRECTORY}/KeepMeUp.app"
ln -s /Applications "${DMG_STAGING_DIRECTORY}/Applications"
hdiutil create \
    -volname "KeepMeUp" \
    -srcfolder "${DMG_STAGING_DIRECTORY}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}" >/dev/null
(
    cd "${OUTPUT_DIRECTORY}"
    shasum -a 256 "${DMG_FILENAME}" > "${DMG_FILENAME}.sha256"
)

# Prints only artifact paths and sizes; the build contains no credentials or private data.
ls -lh "${DMG_PATH}" "${DMG_PATH}.sha256"
