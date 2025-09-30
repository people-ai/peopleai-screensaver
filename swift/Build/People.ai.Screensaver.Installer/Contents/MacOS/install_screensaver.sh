#!/bin/bash

# People.ai Screensaver Installer Script
# This script installs the screensaver to the user's home directory

set -e

SCREENSAVER_NAME="People.ai.saver"
INSTALL_DIR="$HOME/Library/Screen Savers"
BUNDLE_DIR="$(dirname "$0")/../Resources"

echo "Installing People.ai Screensaver..."

# Create Screen Savers directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Remove existing screensaver if it exists
if [ -d "$INSTALL_DIR/$SCREENSAVER_NAME" ]; then
    echo "Removing existing screensaver..."
    rm -rf "$INSTALL_DIR/$SCREENSAVER_NAME"
fi

# Copy screensaver bundle
if [ -d "$BUNDLE_DIR/$SCREENSAVER_NAME" ]; then
    echo "Installing screensaver..."
    cp -r "$BUNDLE_DIR/$SCREENSAVER_NAME" "$INSTALL_DIR/"
    
    # Set proper permissions
    chmod -R 755 "$INSTALL_DIR/$SCREENSAVER_NAME"
    
    echo "✅ People.ai Screensaver installed successfully!"
    echo ""
    echo "📱 To use the screensaver:"
    echo "1. Open System Preferences > Desktop & Screen Saver"
    echo "2. Select 'People.ai' from the list"
    echo "3. Click 'Screen Saver Options' to configure"
    echo "4. Click 'Test' to preview"
    echo ""
    echo "🔧 Configuration:"
    echo "The screensaver uses the same configuration as the original:"
    echo "- slidesUrl: URL for slides content"
    echo "- stayOnSlideTime: Time per slide (seconds)"
    echo "- zoomForFullScreen: Enable dynamic scaling"
    echo "- And all other original settings"
    echo ""
    echo "📋 Architecture Support:"
    echo "- Intel Macs (x86_64)"
    echo "- Apple Silicon Macs (arm64)"
    echo "- macOS 10.15+ (Catalina and later)"
    
    # Open System Preferences to Screen Saver
    echo ""
    read -p "Would you like to open System Preferences now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open /System/Applications/System\ Preferences.app
    fi
    
else
    echo "❌ Error: Screensaver bundle not found"
    echo "Please ensure the installer package is complete"
    exit 1
fi
