#!/bin/bash

# Installation script for Swift People.ai Screensaver

SCREENSAVER_NAME="People.ai.saver"
INSTALL_DIR="$HOME/Library/Screen Savers"

echo "Installing Swift People.ai Screensaver..."

# Create Screen Savers directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Copy screensaver bundle
if [ -d "Products/$SCREENSAVER_NAME" ]; then
    cp -r "Products/$SCREENSAVER_NAME" "$INSTALL_DIR/"
    echo "Screensaver installed successfully!"
    echo "You can now select 'People.ai' from System Preferences > Desktop & Screen Saver"
else
    echo "Error: Screensaver bundle not found. Please run build_swift_screensaver.sh first."
    exit 1
fi
