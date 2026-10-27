#!/usr/bin/env bash
set -euo pipefail

# Build, sign, and package Topiary.
#
# Distribution channel (CHANNEL):
#   mas   - Mac App Store: sandbox ON, Quit/Force Quit compiled out, output .pkg
#   devid - Developer ID:  hardened runtime, sandbox OFF, full features, output .app (wrap into .dmg separately)
#
# Required env:
#   SIGNING_IDENTITY   - codesign identity
#                        mas:   "Apple Distribution: ... (TEAMID)" or "3rd Party Mac Developer Application: ..."
#                        devid: "Developer ID Application: ... (TEAMID)"
# Optional env:
#   CHANNEL            - mas | devid, default mas
#   APP_VERSION        - marketing version, e.g. 1.14.0
#   BUILD_NUMBER       - build version, default 1
#   BUNDLE_ID          - default com.jiangcheng.MacStatusApp
#   PRODUCT            - app/product name, default "Topiary"
#   ARCHS              - space-separated archs, default "arm64 x86_64" (universal)
#   INSTALLER_IDENTITY - pkg signing identity (mas only), defaults to SIGNING_IDENTITY
#   PROVISIONING_PROFILE - path to .mobileprovision to embed (mas only)

CHANNEL="${CHANNEL:-mas}"
PRODUCT="${PRODUCT:-Topiary}"
# SwiftPM executable product name. The package/target are topiary-bar while
# the .app display name is "Topiary", so binary name and bundle name differ.
SPM_PRODUCT="topiary-bar"
BUNDLE_ID="${BUNDLE_ID:-com.jiangcheng.MacStatusApp}"
APP_VERSION="${APP_VERSION:-0.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHS="${ARCHS:-arm64 x86_64}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:?SIGNING_IDENTITY is required}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY-$SIGNING_IDENTITY}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-14.0}"

case "$CHANNEL" in
  mas)
    ENTITLEMENTS_NAME="topiary-bar.entitlements"
    # Sandboxed MAS build: strip Quit / Force Quit (NSRunningApplication is blocked in sandbox).
    SWIFT_DEFINES=(-Xswiftc -D -Xswiftc MAC_APP_STORE)
    ;;
  devid)
    ENTITLEMENTS_NAME="DeveloperID.entitlements"
    SWIFT_DEFINES=()
    ;;
  *)
    echo "unknown CHANNEL: $CHANNEL (expected mas or devid)" >&2
    exit 1
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

# SwiftPM has no SWIFTPM_HOME variable (it is silently ignored), so its cache,
# config and security directories are isolated explicitly under .build/.
SPM_ISOLATION=(
  --cache-path "$ROOT_DIR/.build/spm/cache"
  --config-path "$ROOT_DIR/.build/spm/config"
  --security-path "$ROOT_DIR/.build/spm/security"
)
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"

# SwiftUI's macro plugins (@State, @Bindable, ...) ship with Xcode; with a
# CommandLineTools-only selection swiftc fails with
# "plugin for module 'SwiftUIMacros' not found".
case "$(xcode-select -p 2>/dev/null)" in
  *CommandLineTools*)
    echo "warning: active developer directory is '$(xcode-select -p)'." >&2
    echo "         Run 'sudo xcodebuild -license accept' and" >&2
    echo "         'sudo xcode-select -s /Applications/Xcode.app/Contents/Developer' first." >&2
    ;;
esac
APP_BUNDLE="$DIST_DIR/$PRODUCT.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
PKG_PATH="$DIST_DIR/$PRODUCT.pkg"
ENTITLEMENTS="$ROOT_DIR/Sources/topiary-bar/Resources/$ENTITLEMENTS_NAME"

ARCH_FLAGS=()
for a in $ARCHS; do ARCH_FLAGS+=(--arch "$a"); done

# bash 3.2 (macOS) safe expansion of a possibly empty array under `set -u`.
DEFINES=(${SWIFT_DEFINES[@]+"${SWIFT_DEFINES[@]}"})

echo "==> Building release binary (channel: $CHANNEL, archs: $ARCHS)"
swift build --disable-sandbox "${SPM_ISOLATION[@]}" -c release "${ARCH_FLAGS[@]}" ${DEFINES[@]+"${DEFINES[@]}"} --scratch-path "$ROOT_DIR/.build"
BIN_DIR="$(swift build --disable-sandbox "${SPM_ISOLATION[@]}" -c release "${ARCH_FLAGS[@]}" ${DEFINES[@]+"${DEFINES[@]}"} --scratch-path "$ROOT_DIR/.build" --show-bin-path)"
BINARY="$BIN_DIR/$SPM_PRODUCT"
[ -f "$BINARY" ] || { echo "binary not found: $BINARY" >&2; exit 1; }

echo "==> Assembling $PRODUCT.app"
rm -rf "$APP_BUNDLE" "$PKG_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BINARY" "$APP_MACOS/$PRODUCT"
chmod +x "$APP_MACOS/$PRODUCT"

cat > "$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$PRODUCT</string>
  <key>CFBundleDisplayName</key>
  <string>$PRODUCT</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Compiling the asset catalog (macOS 26+ path)"
# Two shapes, one source of truth (tools/generate_app_icon.py):
#   Assets.xcassets/AppIcon.appiconset  full-bleed -> Assets.car, read through
#       CFBundleIconName on macOS 26+, where the system applies the icon shape
#       itself. Feeding it pre-rounded artwork gets it double-masked and shrunk.
#   Resources/AppIcon.iconset           masked     -> AppIcon.icns, read through
#       CFBundleIconFile on macOS 14/15, which do not mask .icns at all.
# Both sets are committed and pinned by `--verify-assets`, so this script needs
# no Python: actool and iconutil only.
xcrun actool \
  --output-format human-readable-text --notices --warnings \
  --app-icon AppIcon \
  --compile "$APP_RESOURCES" \
  --platform macosx --minimum-deployment-target "$MIN_SYSTEM_VERSION" --target-device mac \
  --output-partial-info-plist "$DIST_DIR/assetcatalog_generated_info.plist" \
  "$ROOT_DIR/Sources/topiary-bar/Resources/Assets.xcassets"

echo "==> Generating the pre-Tahoe AppIcon.icns"
# actool also writes its own AppIcon.icns, built from the full-bleed catalog —
# square corners on macOS 14/15. Overwrite it with the masked set.
iconutil -c icns "$ROOT_DIR/Sources/topiary-bar/Resources/AppIcon.iconset" \
  -o "$APP_RESOURCES/AppIcon.icns"

# Privacy manifest: App Store Connect rejects submissions without it, and the
# reason codes it declares (UserDefaults) must match the shipped binary.
cp "$ROOT_DIR/Sources/topiary-bar/Resources/PrivacyInfo.xcprivacy" "$APP_RESOURCES/PrivacyInfo.xcprivacy"
plutil -lint "$APP_RESOURCES/PrivacyInfo.xcprivacy" >/dev/null

if [ "$CHANNEL" = "mas" ] && [ -n "${PROVISIONING_PROFILE:-}" ] && [ -f "$PROVISIONING_PROFILE" ]; then
  cp "$PROVISIONING_PROFILE" "$APP_CONTENTS/embedded.provisionprofile"
fi

echo "==> Codesigning with: $SIGNING_IDENTITY"
if [ "$CHANNEL" = "devid" ]; then
  # Hardened runtime + secure timestamp are mandatory for Developer ID notarization.
  codesign --force --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS" \
    --options runtime --timestamp "$APP_BUNDLE"
else
  codesign --force --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
fi
codesign --verify --deep --strict "$APP_BUNDLE"

if [ "$CHANNEL" = "mas" ]; then
  if [ -n "${INSTALLER_IDENTITY:-}" ]; then
    echo "==> Packaging .pkg with: $INSTALLER_IDENTITY"
    productbuild --component "$APP_BUNDLE" /Applications --sign "$INSTALLER_IDENTITY" "$PKG_PATH"
  else
    echo "==> Packaging .pkg (unsigned — App Store Connect will re-sign)"
    productbuild --component "$APP_BUNDLE" /Applications "$PKG_PATH"
  fi
  echo "==> Done: $PKG_PATH"
else
  echo "==> Done: $APP_BUNDLE"
fi
