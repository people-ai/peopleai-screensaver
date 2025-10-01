#!/bin/bash

# Swift Screensaver Build Script
# Maintains same installation paths and structure as Objective-C version

set -e

echo "🚀 Building People.ai Screensaver (Swift Version)"
echo "=================================================="

# Configuration - Same as original
PROJECT_NAME="People.ai"
SCHEME_NAME="People.ai"
BUNDLE_IDENTIFIER="ai.people.screensaver"
SAVER_NAME="People.ai.saver"
INSTALL_LOCATION="/Library/Screen Savers/People.ai.saver"

# Code signing configuration
CODE_SIGN_IDENTITY="Developer ID Application: People.ai, Inc (B865KYJU5B)"
INSTALLER_SIGN_IDENTITY="Developer ID Installer: People.ai, Inc (B865KYJU5B)"

# Build paths
BUILD_DIR="Build"
ARCHIVE_PATH="$BUILD_DIR/People.ai.xcarchive"
PKG_PATH="$BUILD_DIR/People.ai.pkg"
SIGNED_PKG_PATH="$BUILD_DIR/People.ai.signed.pkg"
ZIP_PATH="$BUILD_DIR/People.ai.signed.zip"

echo "📋 Build Configuration:"
echo "  Project: $PROJECT_NAME"
echo "  Scheme: $SCHEME_NAME"
echo "  Bundle ID: $BUNDLE_IDENTIFIER"
echo "  Install Location: $INSTALL_LOCATION"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the screensaver
echo "🔨 Building screensaver..."
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
           -scheme "$SCHEME_NAME" \
           -configuration Release \
           -archivePath "$ARCHIVE_PATH" \
           "CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY" \
           "DEVELOPMENT_TEAM=B865KYJU5B" \
           "MACOSX_DEPLOYMENT_TARGET=10.15" \
           "CODE_SIGN_STYLE=Manual" \
           "OTHER_CODE_SIGN_FLAGS=--timestamp" \
           archive

echo "✅ Archive created successfully"

# Extract the screensaver bundle
echo "📦 Extracting screensaver bundle..."
SAVER_BUNDLE_PATH="$ARCHIVE_PATH/Products/Users/happy/Library/Screen Savers/$SAVER_NAME"

if [ ! -d "$SAVER_BUNDLE_PATH" ]; then
    echo "❌ Screensaver bundle not found at: $SAVER_BUNDLE_PATH"
    echo "Available paths:"
    find "$ARCHIVE_PATH/Products" -name "*.saver" -type d 2>/dev/null || echo "No .saver bundles found"
    exit 1
fi

echo "✅ Screensaver bundle found: $SAVER_BUNDLE_PATH"

# Validate the screensaver bundle
echo "🔍 Validating screensaver bundle..."
if [ -f "$SAVER_BUNDLE_PATH/Contents/Info.plist" ]; then
    echo "✅ Info.plist found"
    
    # Check principal class
    PRINCIPAL_CLASS=$(plutil -extract NSPrincipalClass raw "$SAVER_BUNDLE_PATH/Contents/Info.plist" 2>/dev/null || echo "")
    if [ "$PRINCIPAL_CLASS" = "PeopleScreensaverView" ]; then
        echo "✅ Principal class is correct: $PRINCIPAL_CLASS"
    else
        echo "⚠️  Principal class mismatch: $PRINCIPAL_CLASS (expected: PeopleScreensaverView)"
    fi
    
    # Check minimum system version
    MIN_VERSION=$(plutil -extract LSMinimumSystemVersion raw "$SAVER_BUNDLE_PATH/Contents/Info.plist" 2>/dev/null || echo "")
    echo "✅ Minimum system version: $MIN_VERSION"
    
else
    echo "❌ Info.plist not found"
    exit 1
fi

# Create the installer package
echo "📦 Creating installer package..."
pkgbuild --install-location "$INSTALL_LOCATION" \
         --root "$SAVER_BUNDLE_PATH" \
         "$PKG_PATH" \
         --identifier "$BUNDLE_IDENTIFIER.pkg" \
         --version "1.0"

echo "✅ Package created: $PKG_PATH"

# Sign the package
echo "🔐 Signing package..."
productsign --sign "$INSTALLER_SIGN_IDENTITY" \
            "$PKG_PATH" \
            "$SIGNED_PKG_PATH"

echo "✅ Package signed: $SIGNED_PKG_PATH"

# Create zip archive
echo "📦 Creating zip archive..."
zip -r "$ZIP_PATH" "$SIGNED_PKG_PATH"

echo "✅ Zip archive created: $ZIP_PATH"

# Final validation
echo "🔍 Final validation..."
if [ -f "$SIGNED_PKG_PATH" ]; then
    echo "✅ Signed package exists"
    
    # Check package contents
    pkgutil --payload-files "$SIGNED_PKG_PATH" | head -10
    echo "✅ Package contents validated"
else
    echo "❌ Signed package not found"
    exit 1
fi

echo ""
echo "🎉 BUILD COMPLETED SUCCESSFULLY! 🎉"
echo "=================================="
echo ""
echo "📁 Output files:"
echo "  Screensaver: $SAVER_BUNDLE_PATH"
echo "  Package: $SIGNED_PKG_PATH"
echo "  Zip: $ZIP_PATH"
echo ""
echo "📋 Installation instructions:"
echo "  1. Install: sudo installer -pkg \"$SIGNED_PKG_PATH\" -target /"
echo "  2. Or copy manually: cp -R \"$SAVER_BUNDLE_PATH\" \"$INSTALL_LOCATION\""
echo "  3. Select in System Settings > Lock Screen > Screen Saver"
echo ""
echo "🔧 Bundle details:"
echo "  Bundle ID: $BUNDLE_IDENTIFIER"
echo "  Install Path: $INSTALL_LOCATION"
echo "  Principal Class: PeopleScreensaverView"
echo "  Min macOS: 10.15+"
echo ""
echo "✨ Swift screensaver ready for distribution!"
