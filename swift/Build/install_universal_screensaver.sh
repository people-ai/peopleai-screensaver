#!/bin/bash

# Installation script for Universal Swift People.ai Screensaver

SCREENSAVER_NAME="People.ai.saver"
INSTALL_DIR="$HOME/Library/Screen Savers"

echo "Installing Universal Swift People.ai Screensaver..."

# Create Screen Savers directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Remove existing screensaver if it exists
if [ -d "$INSTALL_DIR/$SCREENSAVER_NAME" ]; then
    echo "Removing existing screensaver..."
    rm -rf "$INSTALL_DIR/$SCREENSAVER_NAME"
fi

# Copy screensaver bundle
if [ -d "Products/$SCREENSAVER_NAME" ]; then
    echo "Copying universal screensaver bundle..."
    cp -r "Products/$SCREENSAVER_NAME" "$INSTALL_DIR/"
    echo "Universal screensaver installed successfully!"
    echo "You can now select 'People.ai' from System Preferences > Desktop & Screen Saver"
    echo ""
    echo "Architecture support:"
    echo "- Intel Macs (x86_64)"
    echo "- Apple Silicon Macs (arm64)"
    echo "- macOS 10.15+ (Catalina and later)"
    echo ""
    echo "To test the screensaver:"
    echo "1. Open System Preferences > Desktop & Screen Saver"
    echo "2. Select 'People.ai' from the list"
    echo "3. Click 'Screen Saver Options' to configure"
    echo "4. Click 'Test' to preview"
else
    echo "Error: Screensaver bundle not found. Please run build_universal_screensaver.sh first."
    exit 1
fi
