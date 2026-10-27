#!/usr/bin/env bash
set -euo pipefail

# Builds a locally signed .app for day-to-day development. Sandbox is OFF (same
# as the Developer ID channel in release.sh), so this uses the direct-distribution
# bundle ID together with the Developer ID entitlements.

MODE="${1:-run}"
APP_NAME="Topiary"
# SwiftPM executable product name. The package/target are topiary-bar while
# the .app display name is "Topiary", so binary name and bundle name differ.
SPM_PRODUCT="topiary-bar"
BUNDLE_ID="com.jiangcheng.EasyBar"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Sources/topiary-bar/Resources/DeveloperID.entitlements"

# SwiftPM has no SWIFTPM_HOME variable (it is silently ignored), so its cache,
# config and security directories are isolated explicitly instead of touching
# ~/.swiftpm.
SPM_ISOLATION=(
  --cache-path "$ROOT_DIR/.build/spm/cache"
  --config-path "$ROOT_DIR/.build/spm/config"
  --security-path "$ROOT_DIR/.build/spm/security"
)
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"

# SwiftUI's macro plugins (@State, @Bindable, ...) ship with Xcode. With a
# CommandLineTools-only selection swiftc fails with
# "plugin for module 'SwiftUIMacros' not found", so warn early with the fix.
case "$(xcode-select -p 2>/dev/null)" in
  *CommandLineTools*)
    echo "warning: active developer directory is '$(xcode-select -p)'." >&2
    echo "         A full Xcode selection is required to compile SwiftUI code:" >&2
    echo "           sudo xcodebuild -license accept" >&2
    echo "           sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    ;;
esac

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build --disable-sandbox "${SPM_ISOLATION[@]}" --scratch-path "$ROOT_DIR/.build"
BUILD_BINARY="$(swift build --disable-sandbox "${SPM_ISOLATION[@]}" --scratch-path "$ROOT_DIR/.build" --show-bin-path)/$SPM_PRODUCT"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cp "$ROOT_DIR/Sources/topiary-bar/Resources/PrivacyInfo.xcprivacy" "$APP_RESOURCES/PrivacyInfo.xcprivacy"

# Icons. Until now the dev bundle shipped no icon at all (no CFBundleIconFile,
# no .icns, no actool), so "look at the icon on a real machine" had no path
# through the daily build — every icon review had to go through release.sh.
# Same two shapes as release.sh: full-bleed catalog -> Assets.car for macOS 26+,
# masked iconset -> AppIcon.icns for macOS 14/15.
xcrun actool \
  --output-format human-readable-text --notices --warnings \
  --app-icon AppIcon \
  --compile "$APP_RESOURCES" \
  --platform macosx --minimum-deployment-target "$MIN_SYSTEM_VERSION" --target-device mac \
  --output-partial-info-plist "$ROOT_DIR/.build/assetcatalog_generated_info.plist" \
  "$ROOT_DIR/Sources/topiary-bar/Resources/Assets.xcassets" >/dev/null
iconutil -c icns "$ROOT_DIR/Sources/topiary-bar/Resources/AppIcon.iconset" \
  -o "$APP_RESOURCES/AppIcon.icns"

/usr/bin/codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE" >/dev/null
open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
