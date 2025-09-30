#!/bin/bash

# Build script for Swift People.ai Screensaver
# This script creates a proper screensaver bundle

set -e

# Configuration
SCREENSAVER_NAME="People.ai.saver"
BUILD_DIR="Build"
PRODUCT_DIR="Products"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Swift People.ai Screensaver${NC}"

# Create build directories
mkdir -p "$BUILD_DIR"
mkdir -p "$PRODUCT_DIR"

# Create the screensaver bundle structure
SCREENSAVER_BUNDLE="$PRODUCT_DIR/$SCREENSAVER_NAME"
mkdir -p "$SCREENSAVER_BUNDLE/Contents/MacOS"
mkdir -p "$SCREENSAVER_BUNDLE/Contents/Resources"

# Compile Swift files as a dynamic library for screensaver
echo -e "${YELLOW}Compiling Swift screensaver...${NC}"

swiftc -target x86_64-apple-macosx10.15 \
       -framework ScreenSaver \
       -framework WebKit \
       -framework CoreImage \
       -framework AppKit \
       -framework Foundation \
       -emit-library \
       -o "$SCREENSAVER_BUNDLE/Contents/MacOS/People.ai" \
       PeopleScreensaverView.swift \
       ScreensaverWebView.swift \
       ConfigurationManager.swift \
       SlideManager.swift \
       DisplayScaler.swift \
       AnimationManager.swift \
       BackgroundEffectManager.swift

# Copy Info.plist
cp Info.plist "$SCREENSAVER_BUNDLE/Contents/"

# Set permissions
chmod +x "$SCREENSAVER_BUNDLE/Contents/MacOS/People.ai"

echo -e "${GREEN}Swift screensaver compiled successfully!${NC}"
echo -e "${YELLOW}Screensaver bundle: $SCREENSAVER_BUNDLE${NC}"

# Create installation script
cat > "$BUILD_DIR/install_swift_screensaver.sh" << 'EOF'
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
    echo "Error: Screensaver bundle not found. Please run build_screensaver.sh first."
    exit 1
fi
EOF

chmod +x "$BUILD_DIR/install_swift_screensaver.sh"

echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${YELLOW}To install the screensaver, run:${NC}"
echo -e "${YELLOW}  ./$BUILD_DIR/install_swift_screensaver.sh${NC}"
echo -e "${YELLOW}Or manually copy $SCREENSAVER_BUNDLE to ~/Library/Screen Savers/${NC}"
