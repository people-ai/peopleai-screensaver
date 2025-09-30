#!/bin/bash

# Build script for Swift People.ai Screensaver
# This script creates an Xcode project and builds the screensaver

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

# Create Xcode project
echo -e "${YELLOW}Creating Xcode project...${NC}"

# Create project.pbxproj
cat > "$BUILD_DIR/People.ai.swift.xcodeproj/project.pbxproj" << 'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		A1234567890123456789012A /* PeopleScreensaverView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1234567890123456789012B /* PeopleScreensaverView.swift */; };
		A1234567890123456789012C /* ScreensaverWebView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1234567890123456789012D /* ScreensaverWebView.swift */; };
		A1234567890123456789012E /* ConfigurationManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1234567890123456789012F /* ConfigurationManager.swift */; };
		A1234567890123456789013A /* SlideManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1234567890123456789013B /* SlideManager.swift */; };
		A1234567890123456789013C /* DisplayScaler.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1234567890123456789013D /* DisplayScaler.swift */; };
		A1234567890123456789013E /* AnimationManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1234567890123456789013F /* AnimationManager.swift */; };
		A1234567890123456789014A /* BackgroundEffectManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = A1234567890123456789014B /* BackgroundEffectManager.swift */; };
		A1234567890123456789014C /* Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = A1234567890123456789014D /* Info.plist */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		A1234567890123456789012B /* PeopleScreensaverView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "PeopleScreensaverView.swift"; sourceTree = "<group>"; };
		A1234567890123456789012D /* ScreensaverWebView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "ScreensaverWebView.swift"; sourceTree = "<group>"; };
		A1234567890123456789012F /* ConfigurationManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "ConfigurationManager.swift"; sourceTree = "<group>"; };
		A1234567890123456789013B /* SlideManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "SlideManager.swift"; sourceTree = "<group>"; };
		A1234567890123456789013D /* DisplayScaler.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "DisplayScaler.swift"; sourceTree = "<group>"; };
		A1234567890123456789013F /* AnimationManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "AnimationManager.swift"; sourceTree = "<group>"; };
		A1234567890123456789014B /* BackgroundEffectManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "BackgroundEffectManager.swift"; sourceTree = "<group>"; };
		A1234567890123456789014D /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Info.plist"; sourceTree = "<group>"; };
		A1234567890123456789014E /* People.ai.saver */ = {isa = PBXFileReference; explicitFileType = wrapper.plug-in; includeInIndex = 0; path = "People.ai.saver"; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		A1234567890123456789014F /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		A1234567890123456789015A /* Products */ = {
			isa = PBXGroup;
			children = (
				A1234567890123456789014E /* People.ai.saver */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		A1234567890123456789015B = {
			isa = PBXGroup;
			children = (
				A1234567890123456789015C /* People.ai Swift Screensaver */,
				A1234567890123456789015A /* Products */,
			);
			sourceTree = "<group>";
		};
		A1234567890123456789015C /* People.ai Swift Screensaver */ = {
			isa = PBXGroup;
			children = (
				A1234567890123456789012B /* PeopleScreensaverView.swift */,
				A1234567890123456789012D /* ScreensaverWebView.swift */,
				A1234567890123456789012F /* ConfigurationManager.swift */,
				A1234567890123456789013B /* SlideManager.swift */,
				A1234567890123456789013D /* DisplayScaler.swift */,
				A1234567890123456789013F /* AnimationManager.swift */,
				A1234567890123456789014B /* BackgroundEffectManager.swift */,
				A1234567890123456789014D /* Info.plist */,
			);
			path = "People.ai Swift Screensaver";
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		A1234567890123456789015D /* People.ai Swift Screensaver */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A1234567890123456789015E /* Build configuration list for PBXNativeTarget "People.ai Swift Screensaver" */;
			buildPhases = (
				A1234567890123456789015F /* Sources */,
				A1234567890123456789014F /* Frameworks */,
				A1234567890123456789016A /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = "People.ai Swift Screensaver";
			productName = "People.ai Swift Screensaver";
			productReference = A1234567890123456789014E /* People.ai.saver */;
			productType = "com.apple.product-type.screensaver";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		A1234567890123456789016B /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					A1234567890123456789015D = {
						CreatedOnToolsVersion = 15.0;
					};
				};
			};
			buildConfigurationList = A1234567890123456789016C /* Build configuration list for PBXProject "People.ai Swift Screensaver" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = A1234567890123456789015B;
			productRefGroup = A1234567890123456789015A /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				A1234567890123456789015D /* People.ai Swift Screensaver */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		A1234567890123456789016A /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A1234567890123456789014C /* Info.plist in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		A1234567890123456789015F /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A1234567890123456789012A /* PeopleScreensaverView.swift in Sources */,
				A1234567890123456789012C /* ScreensaverWebView.swift in Sources */,
				A1234567890123456789012E /* ConfigurationManager.swift in Sources */,
				A1234567890123456789013A /* SlideManager.swift in Sources */,
				A1234567890123456789013C /* DisplayScaler.swift in Sources */,
				A1234567890123456789013E /* AnimationManager.swift in Sources */,
				A1234567890123456789014A /* BackgroundEffectManager.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		A1234567890123456789016D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MACOSX_DEPLOYMENT_TARGET = 10.15;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		A1234567890123456789016E /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MACOSX_DEPLOYMENT_TARGET = 10.15;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
			};
			name = Release;
		};
		A1234567890123456789016F /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "People.ai Swift Screensaver/People.ai Swift Screensaver.entitlements";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "People.ai Swift Screensaver/Info.plist";
				INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright © 2020-2024 People.ai, Inc. All rights reserved.";
				INFOPLIST_KEY_NSPrincipalClass = PeopleScreensaverView;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 2.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.peopleai.screensaver.swift;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		A1234567890123456789017A /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "People.ai Swift Screensaver/People.ai Swift Screensaver.entitlements";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "People.ai Swift Screensaver/Info.plist";
				INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright © 2020-2024 People.ai, Inc. All rights reserved.";
				INFOPLIST_KEY_NSPrincipalClass = PeopleScreensaverView;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 2.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.peopleai.screensaver.swift;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		A1234567890123456789015E /* Build configuration list for PBXNativeTarget "People.ai Swift Screensaver" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				A1234567890123456789016F /* Debug */,
				A1234567890123456789017A /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		A1234567890123456789016C /* Build configuration list for PBXProject "People.ai Swift Screensaver" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				A1234567890123456789016D /* Debug */,
				A1234567890123456789016E /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = A1234567890123456789016B /* Project object */;
}
EOF

# Create project directory structure
mkdir -p "$BUILD_DIR/People.ai Swift Screensaver.xcodeproj"
mkdir -p "$BUILD_DIR/People.ai Swift Screensaver"

# Copy source files to project directory
cp *.swift "$BUILD_DIR/People.ai Swift Screensaver/"
cp Info.plist "$BUILD_DIR/People.ai Swift Screensaver/"

# Build the project
echo -e "${YELLOW}Building with xcodebuild...${NC}"
cd "$BUILD_DIR"
xcodebuild -project "People.ai Swift Screensaver.xcodeproj" \
           -target "People.ai Swift Screensaver" \
           -configuration Release \
           -derivedDataPath DerivedData \
           build

# Copy the built screensaver to products directory
echo -e "${YELLOW}Copying built screensaver...${NC}"
cp -r "DerivedData/Build/Products/Release/People.ai.saver" "../$PRODUCT_DIR/"

echo -e "${GREEN}Swift screensaver built successfully!${NC}"
echo -e "${YELLOW}Screensaver bundle: $PRODUCT_DIR/People.ai.saver${NC}"
