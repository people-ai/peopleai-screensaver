#!/bin/bash

# Build script for Swift People.ai Screensaver
# This script compiles the Swift screensaver and creates a distributable package

set -e

# Configuration
PROJECT_NAME="People.ai Swift Screensaver"
BUNDLE_ID="com.peopleai.screensaver.swift"
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

# Compile Swift screensaver
echo -e "${YELLOW}Compiling Swift screensaver...${NC}"

# Create the screensaver bundle structure
SCREENSAVER_BUNDLE="$PRODUCT_DIR/$SCREENSAVER_NAME"
mkdir -p "$SCREENSAVER_BUNDLE/Contents/MacOS"
mkdir -p "$SCREENSAVER_BUNDLE/Contents/Resources"

# Compile Swift files as a dynamic library
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

# Create Resources directory and copy any resources
if [ -d "Resources" ]; then
    cp -r Resources/* "$SCREENSAVER_BUNDLE/Contents/Resources/"
fi

# Set permissions
chmod +x "$SCREENSAVER_BUNDLE/Contents/MacOS/People.ai"

echo -e "${GREEN}Swift screensaver compiled successfully!${NC}"
echo -e "${YELLOW}Screensaver bundle: $SCREENSAVER_BUNDLE${NC}"

# Create installer package (optional)
if command -v pkgbuild &> /dev/null; then
    echo -e "${YELLOW}Creating installer package...${NC}"
    
    # Create component plist
    cat > "$BUILD_DIR/component.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>BundleHasStrictIdentifier</key>
    <true/>
    <key>BundleIsRelocatable</key>
    <false/>
    <key>BundleIsVersionChecked</key>
    <true/>
    <key>BundleOverwriteAction</key>
    <string>upgrade</string>
    <key>RootRelativeBundlePath</key>
    <string>Library/Screen Savers/$SCREENSAVER_NAME</string>
</dict>
</plist>
EOF

    # Build package
    pkgbuild --root "$PRODUCT_DIR" \
             --component-plist "$BUILD_DIR/component.plist" \
             --identifier "$BUNDLE_ID" \
             --version "2.0" \
             --install-location "/" \
             "$BUILD_DIR/People.ai.swift.pkg"
    
    echo -e "${GREEN}Installer package created: $BUILD_DIR/People.ai.swift.pkg${NC}"
fi

# Create distribution script
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
    echo "Error: Screensaver bundle not found. Please run build_swift_screensaver.sh first."
    exit 1
fi
EOF

chmod +x "$BUILD_DIR/install_swift_screensaver.sh"

echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${YELLOW}To install the screensaver, run:${NC}"
echo -e "${YELLOW}  ./$BUILD_DIR/install_swift_screensaver.sh${NC}"
echo -e "${YELLOW}Or manually copy $SCREENSAVER_BUNDLE to ~/Library/Screen Savers/${NC}"
