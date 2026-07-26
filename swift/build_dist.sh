#!/bin/bash
#
# Distribution build for the Swift People.ai screensaver.
#
# Produces a universal (arm64 + x86_64), Developer-ID-signed, notarized and
# stapled installer pkg suitable for MDM deployment. Requires only the Xcode
# Command Line Tools (no Xcode.app): swiftc, lipo, codesign, pkgbuild,
# productsign, notarytool, stapler.
#
# Prerequisites (one-time, on this machine):
#   1. "Developer ID Application: People.ai, Inc (B865KYJU5B)" cert + private
#      key in the login keychain.
#   2. "Developer ID Installer: People.ai, Inc (B865KYJU5B)" cert + private
#      key in the login keychain.
#   3. Notarization credentials stored as a keychain profile:
#        xcrun notarytool store-credentials "People-ai" \
#          --apple-id <apple-id-email> --team-id B865KYJU5B
#      (prompts for an app-specific password from account.apple.com)
#
# Usage: ./build_dist.sh [--skip-notarize]

set -euo pipefail
cd "$(dirname "$0")"

# --- Configuration ---------------------------------------------------------
VERSION="1.1"
BUILD_NUMBER="2"
BUNDLE_ID="ai.people.screensaver"
APP_SIGN_IDENTITY="Developer ID Application: People.ai, Inc (B865KYJU5B)"
PKG_SIGN_IDENTITY="Developer ID Installer: People.ai, Inc (B865KYJU5B)"
KEYCHAIN_PROFILE="People-ai"
MIN_MACOS="10.15"

DIST_DIR="Build/dist"
SAVER="$DIST_DIR/People.ai.saver"
PKG_UNSIGNED="$DIST_DIR/People.ai.unsigned.pkg"
PKG_SIGNED="$DIST_DIR/People.ai-$VERSION.pkg"
SOURCES=(People.ai/PeopleScreensaverView.swift People.ai/CacheManager.swift People.ai/WKWebViewCustom.swift)
SDK="$(xcrun --sdk macosx --show-sdk-path)"

SKIP_NOTARIZE=0
[[ "${1:-}" == "--skip-notarize" ]] && SKIP_NOTARIZE=1

# --- Preflight checks ------------------------------------------------------
fail() { echo "ERROR: $1" >&2; exit 1; }

security find-identity -v -p codesigning | grep -q "$APP_SIGN_IDENTITY" \
  || fail "'$APP_SIGN_IDENTITY' not found in keychain (import the .p12 first)"
security find-identity -v | grep -q "Developer ID Installer" \
  || fail "'$PKG_SIGN_IDENTITY' not found in keychain (import the .p12 first)"
if [[ $SKIP_NOTARIZE -eq 0 ]]; then
  xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1 \
    || fail "notarytool keychain profile '$KEYCHAIN_PROFILE' not found (run store-credentials first)"
fi

# --- 1. Compile universal binary -------------------------------------------
echo "==> Compiling (arm64 + x86_64, optimized)"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

for ARCH in arm64 x86_64; do
  swiftc -sdk "$SDK" -target "$ARCH-apple-macosx$MIN_MACOS" \
    -emit-library -o "$DIST_DIR/People.ai.$ARCH" \
    -Xlinker -bundle -module-name People_ai -O \
    "${SOURCES[@]}"
done
lipo -create "$DIST_DIR/People.ai.arm64" "$DIST_DIR/People.ai.x86_64" \
  -output "$DIST_DIR/People.ai.bin"
rm -f "$DIST_DIR/People.ai.arm64" "$DIST_DIR/People.ai.x86_64"

# --- 2. Assemble .saver bundle ----------------------------------------------
echo "==> Assembling bundle (v$VERSION build $BUILD_NUMBER)"
mkdir -p "$SAVER/Contents/MacOS" "$SAVER/Contents/Resources"
mv "$DIST_DIR/People.ai.bin" "$SAVER/Contents/MacOS/People.ai"
cp People.ai/error.html "$SAVER/Contents/Resources/error.html"

cat > "$SAVER/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>People.ai</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>People.ai</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © People.ai, Inc. All rights reserved.</string>
	<key>NSPrincipalClass</key>
	<string>PeopleScreensaverView</string>
	<key>LSMinimumSystemVersion</key>
	<string>$MIN_MACOS</string>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
		<key>NSAllowsArbitraryLoadsInWebContent</key>
		<true/>
	</dict>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<true/>
</dict>
</plist>
PLIST
plutil -lint "$SAVER/Contents/Info.plist"

# --- 3. Codesign (hardened runtime + secure timestamp: required to notarize) -
echo "==> Codesigning bundle"
codesign --force --options runtime --timestamp \
  --sign "$APP_SIGN_IDENTITY" "$SAVER"
codesign --verify --strict --verbose=2 "$SAVER"

# --- 4. Build + sign installer pkg ------------------------------------------
echo "==> Building installer pkg"
pkgbuild --component "$SAVER" \
  --install-location "/Library/Screen Savers" \
  --identifier "$BUNDLE_ID" --version "$VERSION" \
  "$PKG_UNSIGNED"
productsign --timestamp --sign "$PKG_SIGN_IDENTITY" "$PKG_UNSIGNED" "$PKG_SIGNED"
rm -f "$PKG_UNSIGNED"

# --- 5. Notarize + staple ----------------------------------------------------
if [[ $SKIP_NOTARIZE -eq 1 ]]; then
  echo "==> Skipping notarization (--skip-notarize)"
else
  echo "==> Submitting for notarization (may take several minutes)"
  xcrun notarytool submit "$PKG_SIGNED" --keychain-profile "$KEYCHAIN_PROFILE" --wait
  echo "==> Stapling ticket"
  xcrun stapler staple "$PKG_SIGNED"
  xcrun stapler validate "$PKG_SIGNED"
  spctl --assess --type install --verbose=2 "$PKG_SIGNED" || true
fi

echo ""
echo "Done: $PKG_SIGNED"
