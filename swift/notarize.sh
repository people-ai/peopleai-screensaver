#!/bin/bash

# Swift Screensaver Notarization Script
# Maintains same notarization process as original

set -e

echo "🔐 Notarizing People.ai Screensaver (Swift Version)"
echo "=================================================="

# Configuration
KEYCHAIN_PROFILE_NAME="PICpic123!@#"
SIGNED_PKG_PATH="Build/People.ai.signed.pkg"
NOTARIZED_PKG_PATH="Build/People.ai.notarized.pkg"

# Check if signed package exists
if [ ! -f "$SIGNED_PKG_PATH" ]; then
    echo "❌ Signed package not found: $SIGNED_PKG_PATH"
    echo "Please run build_screensaver.sh first"
    exit 1
fi

echo "📦 Found signed package: $SIGNED_PKG_PATH"

# Submit for notarization
echo "🚀 Submitting package for notarization..."
xcrun notarytool submit "$SIGNED_PKG_PATH" \
                   --keychain-profile "$KEYCHAIN_PROFILE_NAME" \
                   --wait

echo "✅ Notarization successful"

# Staple the notarization ticket
echo "📎 Stapling notarization ticket..."
xcrun stapler staple "$SIGNED_PKG_PATH"

echo "✅ Stapling successful"

# Verify notarization
echo "🔍 Verifying notarization..."
spctl --assess --verbose "$SIGNED_PKG_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Notarization verification successful"
else
    echo "❌ Notarization verification failed"
    exit 1
fi

echo ""
echo "🎉 NOTARIZATION COMPLETED SUCCESSFULLY! 🎉"
echo "=========================================="
echo ""
echo "📦 Notarized package: $SIGNED_PKG_PATH"
echo "✅ Ready for distribution"
echo ""
echo "🔧 Verification commands:"
echo "  spctl --assess --verbose \"$SIGNED_PKG_PATH\""
echo "  xcrun stapler validate \"$SIGNED_PKG_PATH\""
echo ""
echo "✨ Package is now notarized and ready for distribution!"
