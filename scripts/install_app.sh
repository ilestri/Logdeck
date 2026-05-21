#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-Logdeck}"
BUNDLE_ID="${BUNDLE_ID:-com.ilestri.logdeck}"
VERSION="${VERSION:-0.1.0}"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)}"
DIST_DIR="${DIST_DIR:-"$ROOT_DIR/dist"}"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_NAME="${ICON_NAME:-Logdeck}"
ICON_SOURCE="${ICON_SOURCE:-"$ROOT_DIR/Resources/$ICON_NAME.icns"}"
OPEN_APP="${OPEN_APP:-1}"

if [[ -z "${INSTALL_DIR:-}" ]]; then
  if [[ -w "/Applications" ]]; then
    INSTALL_DIR="/Applications"
  else
    INSTALL_DIR="$HOME/Applications"
  fi
fi

swift build -c "$BUILD_CONFIG" --package-path "$ROOT_DIR"
BIN_DIR="$(swift build -c "$BUILD_CONFIG" --package-path "$ROOT_DIR" --show-bin-path)"
BINARY_PATH="$BIN_DIR/$APP_NAME"

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Missing executable: $BINARY_PATH" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"
chmod 755 "$MACOS_DIR/$APP_NAME"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing app icon: $ICON_SOURCE" >&2
  exit 1
fi

cp "$ICON_SOURCE" "$RESOURCES_DIR/$ICON_NAME.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>ko</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>ko</string>
  </array>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>로그 파일</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>log</string>
        <string>txt</string>
        <string>json</string>
        <string>jsonl</string>
      </array>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.apple.log</string>
        <string>public.log</string>
        <string>public.plain-text</string>
        <string>public.text</string>
        <string>public.json</string>
        <string>public.data</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeName</key>
      <string>macOS 로그 아카이브</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>logarchive</string>
      </array>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.apple.logarchive</string>
      </array>
    </dict>
  </array>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

printf "APPL????" > "$CONTENTS_DIR/PkgInfo"
plutil -lint "$CONTENTS_DIR/Info.plist"

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp=none \
  --sign - \
  "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

mkdir -p "$INSTALL_DIR"
INSTALL_PATH="$INSTALL_DIR/$APP_NAME.app"
rm -rf "$INSTALL_PATH"
/usr/bin/ditto "$APP_DIR" "$INSTALL_PATH"
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

echo "Installed $INSTALL_PATH"

if [[ "$OPEN_APP" == "1" ]]; then
  open "$INSTALL_PATH"
fi
