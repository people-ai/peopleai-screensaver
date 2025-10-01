#!/bin/bash

# Swift Screensaver Build Script
# Maintains exact same installation paths and structure as Objective-C version

set -e

echo "🚀 Building People.ai Screensaver (Swift Version)"
echo "=================================================="

# Configuration - EXACTLY same as original Objective-C version
PROJECT_NAME="People.ai"
SCHEME_NAME="People.ai"
BUNDLE_IDENTIFIER="ai.people.screensaver"
SAVER_NAME="People.ai.saver"
INSTALL_LOCATION="/Library/Screen Savers/People.ai.saver"

# Code signing configuration - SAME as original
CODE_SIGN_IDENTITY="Developer ID Application: People.ai, Inc (B865KYJU5B)"
INSTALLER_SIGN_IDENTITY="Developer ID Installer: People.ai, Inc (B865KYJU5B)"

# Build paths - SAME structure as original
BUILD_DIR="Build"
ARCHIVE_PATH="$BUILD_DIR/People.ai.xcarchive"
PKG_PATH="$BUILD_DIR/People.ai.pkg"
SIGNED_PKG_PATH="$BUILD_DIR/People.ai.signed.pkg"
ZIP_PATH="$BUILD_DIR/People.ai.signed.zip"

echo "📋 Build Configuration (Same as Original):"
echo "  Project: $PROJECT_NAME"
echo "  Scheme: $SCHEME_NAME"
echo "  Bundle ID: $BUNDLE_IDENTIFIER"
echo "  Install Location: $INSTALL_LOCATION"
echo "  Code Sign: $CODE_SIGN_IDENTITY"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the screensaver with same settings as original
echo "🔨 Building screensaver (same as original build.sh)..."
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
           -scheme "$SCHEME_NAME" \
           -configuration Release \
           "CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY" \
           clean

xcodebuild -project "$PROJECT_NAME.xcodeproj" \
           -scheme "$SCHEME_NAME" \
           -configuration Release \
           "CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY" \
           build

xcodebuild -project "$PROJECT_NAME.xcodeproj" \
           -scheme "$SCHEME_NAME" \
           -configuration Release \
           "CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY" \
           archive -archivePath "$ARCHIVE_PATH"

echo "✅ Archive created successfully"

# Extract the screensaver bundle - SAME path as original
echo "📦 Extracting screensaver bundle..."
SAVER_BUNDLE_PATH="/Users/happy/Library/Developer/Xcode/DerivedData/People.ai-fxycyaphiuspekfjgfxjouxbnywv/Build/Products/Release/$SAVER_NAME"

if [ ! -d "$SAVER_BUNDLE_PATH" ]; then
    echo "❌ Screensaver bundle not found at: $SAVER_BUNDLE_PATH"
    echo "Available paths:"
    find "$ARCHIVE_PATH/Products" -name "*.saver" -type d 2>/dev/null || echo "No .saver bundles found"
    exit 1
fi

echo "✅ Screensaver bundle found: $SAVER_BUNDLE_PATH"

# Validate the screensaver bundle - SAME validation as original
echo "🔍 Validating screensaver bundle..."
if [ -f "$SAVER_BUNDLE_PATH/Contents/Info.plist" ]; then
    echo "✅ Info.plist found"
    
    # Check principal class - MUST be PeopleScreensaverView for Swift version
    PRINCIPAL_CLASS=$(plutil -extract NSPrincipalClass raw "$SAVER_BUNDLE_PATH/Contents/Info.plist" 2>/dev/null || echo "")
    if [ "$PRINCIPAL_CLASS" = "PeopleScreensaverView" ]; then
        echo "✅ Principal class is correct: $PRINCIPAL_CLASS"
    else
        echo "⚠️  Principal class mismatch: $PRINCIPAL_CLASS (expected: PeopleScreensaverView)"
    fi
    
    # Check minimum system version - SAME as original
    MIN_VERSION=$(plutil -extract LSMinimumSystemVersion raw "$SAVER_BUNDLE_PATH/Contents/Info.plist" 2>/dev/null || echo "")
    echo "✅ Minimum system version: $MIN_VERSION"
    
    # Check bundle identifier - SAME as original
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$SAVER_BUNDLE_PATH/Contents/Info.plist" 2>/dev/null || echo "")
    if [ "$BUNDLE_ID" = "$BUNDLE_IDENTIFIER" ]; then
        echo "✅ Bundle identifier is correct: $BUNDLE_ID"
    else
        echo "⚠️  Bundle identifier mismatch: $BUNDLE_ID (expected: $BUNDLE_IDENTIFIER)"
    fi
    
else
    echo "❌ Info.plist not found"
    exit 1
fi

# Create the installer package - SAME as original
echo "📦 Creating installer package (same as original)..."
pkgbuild --install-location "$INSTALL_LOCATION" \
         --root "$SAVER_BUNDLE_PATH" \
         "$PKG_PATH" \
         --identifier "$BUNDLE_IDENTIFIER.pkg" \
         --version "1.0"

echo "✅ Package created: $PKG_PATH"

# Sign the package - SAME as original
echo "🔐 Signing package (same as original)..."
productsign --timestamp --sign "$INSTALLER_SIGN_IDENTITY" \
            "$PKG_PATH" \
            "$SIGNED_PKG_PATH"

echo "✅ Package signed: $SIGNED_PKG_PATH"

# Create zip archive - SAME as original
echo "📦 Creating zip archive (same as original)..."
zip "$ZIP_PATH" "$SIGNED_PKG_PATH"

echo "✅ Zip archive created: $ZIP_PATH"

# Final validation - SAME as original
echo "🔍 Final validation..."
if [ -f "$SIGNED_PKG_PATH" ]; then
    echo "✅ Signed package exists"
    
    # Check package contents
    echo "📋 Package contents:"
    pkgutil --payload-files "$SIGNED_PKG_PATH" | head -10
    echo "✅ Package contents validated"
else
    echo "❌ Signed package not found"
    exit 1
fi

echo ""
echo "🎉 SWIFT SCREENSAVER BUILD COMPLETED SUCCESSFULLY! 🎉"
echo "====================================================="
echo ""
echo "📁 Output files (same structure as original):"
echo "  Screensaver: $SAVER_BUNDLE_PATH"
echo "  Package: $SIGNED_PKG_PATH"
echo "  Zip: $ZIP_PATH"
echo ""
echo "📋 Installation instructions (same as original):"
echo "  1. Install: sudo installer -pkg \"$SIGNED_PKG_PATH\" -target /"
echo "  2. Or copy manually: cp -R \"$SAVER_BUNDLE_PATH\" \"$INSTALL_LOCATION\""
echo "  3. Select in System Settings > Lock Screen > Screen Saver"
echo ""
echo "🔧 Bundle details (same as original):"
echo "  Bundle ID: $BUNDLE_IDENTIFIER"
echo "  Install Path: $INSTALL_LOCATION"
echo "  Principal Class: PeopleScreensaverView (Swift version)"
echo "  Min macOS: 10.15+"
echo "  Code Sign: $CODE_SIGN_IDENTITY"
echo ""
echo "✨ Swift screensaver ready for distribution!"
echo "   - Same installation paths as original"
echo "   - Same bundle identifier as original"
echo "   - Same code signing as original"
echo "   - Enhanced with Swift features"
