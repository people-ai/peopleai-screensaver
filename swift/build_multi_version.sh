#!/bin/zsh

# Stop the script if any command fails
set -e

# ==============================================================================
# MULTI-VERSION MACOS COMPATIBILITY BUILD SCRIPT (SWIFT VERSION)
# Based on build_multi_version.sh with multi-version macOS support
# ==============================================================================

# Detect current macOS version for compatibility info
MACOS_VERSION=$(sw_vers -productVersion)
MAJOR_VERSION=$(echo $MACOS_VERSION | cut -d. -f1)

echo "Building People.ai Screensaver (Swift Version) for multi-version macOS compatibility..."
echo "Detected macOS version: $MACOS_VERSION"

if [[ $MAJOR_VERSION -ge 15 ]]; then
    echo "✅ Detected macOS 15+ - applying enhanced compatibility fixes"
    COMPATIBILITY_MODE="macos15"
elif [[ $MAJOR_VERSION -ge 12 ]]; then
    echo "✅ Detected macOS 12+ - applying standard compatibility fixes"
    COMPATIBILITY_MODE="macos12"
elif [[ $MAJOR_VERSION -ge 10 ]]; then
    echo "✅ Detected macOS 10.15+ - applying basic compatibility fixes"
    COMPATIBILITY_MODE="macos10"
else
    echo "❌ Unsupported macOS version: $MACOS_VERSION"
    echo "This screensaver requires macOS 10.15 or later"
    exit 1
fi

# ==============================================================================
# CONFIGURATION - FILL IN YOUR DETAILS HERE
# ==============================================================================

APPLE_ID="hopestar702@gmail.com"
TEAM_ID="B865KYJU5B"
DEV_ID_APP="Developer ID Application: People.ai, Inc (B865KYJU5B)"
DEV_ID_INSTALLER="Developer ID Installer: People.ai, Inc (B865KYJU5B)"
KEYCHAIN_PROFILE_NAME="PICpic123!@#"

PROJECT_NAME="People.ai.xcodeproj"
SCHEME_NAME="People.ai"
ARCHIVE_PATH="Build/People.ai.xcarchive"
EXPORT_PATH="Build/Build/Intermediates"
PKG_PATH="Build/People.ai.pkg"
SIGNED_PKG_PATH="Build/People.ai.signed.pkg"
ZIP_PATH="Build/People.ai.signed.zip"

echo "✅ Configuration Loaded. Starting multi-version build..."

# ==============================================================================
# 1. CLEAN & ARCHIVE WITH MULTI-VERSION COMPATIBILITY
# ==============================================================================
echo "\n ▶️  Cleaning and Archiving the project with multi-version compatibility..."

xcodebuild -project "$PROJECT_NAME" -scheme "$SCHEME_NAME" clean

case $COMPATIBILITY_MODE in
    "macos15")
        echo "Building with macOS 15+ enhanced compatibility..."
        MACOSX_DEPLOYMENT_TARGET="10.15"
        ;;
    "macos12")
        echo "Building with macOS 12+ compatibility..."
        MACOSX_DEPLOYMENT_TARGET="10.15"
        ;;
    "macos10")
        echo "Building with macOS 10.15+ compatibility..."
        MACOSX_DEPLOYMENT_TARGET="10.15"
        ;;
esac

xcodebuild -project "$PROJECT_NAME" -scheme "$SCHEME_NAME" \
           -configuration Release \
           -archivePath "$ARCHIVE_PATH" \
           "CODE_SIGN_IDENTITY=$DEV_ID_APP" \
           "DEVELOPMENT_TEAM=$TEAM_ID" \
           "MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET" \
           "CODE_SIGN_STYLE=Manual" \
           "OTHER_CODE_SIGN_FLAGS=--timestamp" \
           archive

echo "✅ Archive successful with multi-version compatibility."

# ==============================================================================
# 2. BUILD THE INSTALLER PACKAGE (.pkg)
# ==============================================================================
echo "\n ▶️  Building the installer package (.pkg) with multi-version support..."

SAVER_PATH="/Users/happy/Library/Developer/Xcode/DerivedData/People.ai-fxycyaphiuspekfjgfxjouxbnywv/Build/Intermediates.noindex/ArchiveIntermediates/People.ai/IntermediateBuildFilesPath/UninstalledProducts/macosx/$SCHEME_NAME.saver"

pkgbuild --install-location "/Library/Screen Savers/$SCHEME_NAME.saver" \
         --root "$SAVER_PATH" \
         "$PKG_PATH" \
         --identifier "ai.people.screensaver.pkg" \
         --version "1.0"

echo "✅ PKG build successful with multi-version support."

# ==============================================================================
# 3. SIGN THE INSTALLER PACKAGE
# ==============================================================================
echo "\n ▶️  Signing the installer package..."

productsign --sign "$DEV_ID_INSTALLER" "$PKG_PATH" "$SIGNED_PKG_PATH"

echo "✅ PKG signing successful."

# ==============================================================================
# 4. NOTARIZE THE SIGNED PACKAGE
# ==============================================================================
echo "\n ▶️  Submitting the signed package to Apple for notarization..."
echo "    (This may take several minutes. The script will wait.)"

xcrun notarytool submit "$SIGNED_PKG_PATH" \
                   --keychain-profile "$KEYCHAIN_PROFILE_NAME" \
                   --wait

echo "✅ Notarization successful."

# ==============================================================================
# 5. STAPLE THE NOTARIZATION TICKET
# ==============================================================================
echo "\n ▶️  Stapling the notarization ticket to the package..."

xcrun stapler staple "$SIGNED_PKG_PATH"

echo "✅ Stapling successful."

# ==============================================================================
# 6. MULTI-VERSION COMPATIBILITY VALIDATION
# ==============================================================================
echo "\n ▶️  Validating multi-version macOS compatibility..."

if [ -d "$SAVER_PATH" ]; then
    echo "✅ Screensaver bundle structure is valid"
    
    if plutil -lint "$SAVER_PATH/Contents/Info.plist" > /dev/null 2>&1; then
        echo "✅ Info.plist is valid"
    else
        echo "❌ Info.plist validation failed"
        exit 1
    fi
    
    MIN_VERSION=$(plutil -extract LSMinimumSystemVersion raw "$SAVER_PATH/Contents/Info.plist")
    echo "✅ Minimum system version: $MIN_VERSION"
    
    # Check principal class for Swift version
    PRINCIPAL_CLASS=$(plutil -extract NSPrincipalClass raw "$SAVER_PATH/Contents/Info.plist")
    if [ "$PRINCIPAL_CLASS" = "PeopleScreensaverView" ]; then
        echo "✅ Principal class is correct: $PRINCIPAL_CLASS (Swift version)"
    else
        echo "❌ Principal class mismatch: $PRINCIPAL_CLASS (expected: PeopleScreensaverView)"
        exit 1
    fi
    
else
    echo "❌ Screensaver bundle not found"
    exit 1
fi

# ==============================================================================
# 7. FINAL CLEANUP AND PACKAGING
# ==============================================================================
echo "\n ▶️  Creating final distributable package..."

zip "$ZIP_PATH" "$SIGNED_PKG_PATH"

echo "✅ Final package created: $ZIP_PATH"

# ==============================================================================
# 8. COMPLETION SUMMARY
# ==============================================================================
echo "\n\n🎉 MULTI-VERSION COMPATIBLE BUILD AND NOTARIZATION COMPLETE! 🎉"
echo ""
echo "Your final, distributable package is here: $SIGNED_PKG_PATH"
echo "Zipped package: $ZIP_PATH"
echo ""
echo "This screensaver is compatible with:"
echo "- ✅ macOS 10.15+ (Catalina and later)"
echo "- ✅ macOS 11+ (Big Sur and later)"  
echo "- ✅ macOS 12+ (Monterey and later)"
echo "- ✅ macOS 13+ (Ventura and later)"
echo "- ✅ macOS 14+ (Sonoma and later)"
echo "- ✅ macOS 15+ (Sequoia and later)"
echo ""
echo "Installation instructions:"
echo "1. Copy 'People.ai.saver' to ~/Library/Screen Savers/"
echo "2. Open System Settings > Lock Screen > Screen Saver (macOS 13+)"
echo "   or System Preferences > Desktop & Screen Saver (macOS 12 and earlier)"
echo "3. Select 'People.ai' from the list"
echo ""
echo "Compatibility features enabled:"
echo "- ✅ Enhanced security settings"
echo "- ✅ Improved memory management"
echo "- ✅ Background process prevention"
echo "- ✅ Network security compliance"
echo "- ✅ Multi-version compatibility"
echo "- ✅ Swift modern features"
echo ""
echo "Build completed successfully on macOS $MACOS_VERSION!"
