# People.ai Screensaver - Swift Implementation

A modern Swift re-implementation of the People.ai screensaver with enhanced robustness, performance, and maintainability.

## Features

- **WebKit-based slideshow** with remote content loading
- **Multi-display support** with dynamic scaling for different aspect ratios
- **Advanced caching system** with background slide preloading
- **MDM (Mobile Device Management)** configuration support
- **Background effects** (blur, static images, dynamic modes)
- **Smooth animations** and slide transitions
- **Display detection** and automatic scaling
- **Modern Swift architecture** with async/await and structured error handling

## Architecture

### Core Components

- **`PeopleScreensaverView`** - Main screensaver view inheriting from `ScreenSaverView`
- **`ScreensaverWebView`** - Custom WebView that blocks user interactions
- **`ConfigurationManager`** - Handles MDM and user preferences with type-safe configuration
- **`SlideManager`** - Manages slide loading, caching, and background preloading
- **`DisplayScaler`** - Handles dynamic scaling based on screen properties
- **`AnimationManager`** - Manages slide transitions and visual effects
- **`BackgroundEffectManager`** - Handles background effects (blur, static, dynamic)

### Key Improvements over Objective-C Version

1. **Modern Swift Features**
   - Async/await for better concurrency
   - Result types for structured error handling
   - Codable for type-safe configuration
   - Property wrappers for clean configuration binding

2. **Enhanced Architecture**
   - Separation of concerns with dedicated managers
   - Protocol-oriented design for flexibility
   - Dependency injection for better testing
   - SwiftUI integration where applicable

3. **Improved Robustness**
   - Comprehensive error handling with automatic recovery
   - Better memory management with automatic cleanup
   - Enhanced performance optimizations
   - Modern APIs and latest WebKit features

## Configuration

The Swift screensaver uses the same MDM configuration keys as the original Objective-C version:

- `slidesUrl` - URL for the slides content
- `stayOnSlideTime` - Time to stay on each slide (seconds)
- `resetSlidesWhenStarted` - Whether to reset slides when screensaver starts
- `maxSlides` - Maximum number of slides
- `zoomForFullScreen` - Enable dynamic scaling for full screen
- `viewRefreshTime` - Time interval for refreshing the view
- `fillEmptySpace` - Whether to fill empty space with background
- `dynamic` - Enable dynamic background effects
- `emptySpaceFillImage` - URL for static background image
- `emptySpaceFillMode` - Background mode: "none", "static", or "dynamic"

## Building

### Prerequisites

- macOS 10.15 or later
- Xcode 12.0 or later
- Swift 5.3 or later

### Build Instructions

1. **Compile the screensaver:**
   ```bash
   chmod +x build_swift_screensaver.sh
   ./build_swift_screensaver.sh
   ```

2. **Install the screensaver:**
   ```bash
   ./Build/install_swift_screensaver.sh
   ```

3. **Manual installation:**
   ```bash
   cp -r Products/People.ai.saver ~/Library/Screen\ Savers/
   ```

### Development

To modify the screensaver:

1. Edit the Swift source files in the `swift/` directory
2. Run `./build_swift_screensaver.sh` to compile
3. Test the screensaver in System Preferences > Desktop & Screen Saver

## Configuration Management

The screensaver reads configuration from the same UserDefaults suite as the original:

```swift
let configManager = ConfigurationManager()
let config = configManager.loadConfiguration()

// Access configuration values
if let slidesUrl = config.slidesUrl {
    // Load slides from URL
}
```

## Error Handling

The Swift implementation includes comprehensive error handling:

```swift
enum ScreensaverError: Error, LocalizedError {
    case networkFailure(String)
    case configurationError(String)
    case displayError(String)
    case slideLoadingError(String)
}
```

## Performance Optimizations

- **Async/await** for network operations and animations
- **Background task management** with Task/async
- **Memory-efficient slide storage** with automatic cache cleanup
- **Optimized image processing** with Core Image
- **Better animation performance** with Core Animation

## Memory Management

- Automatic memory cleanup with ARC
- Resource pooling for images
- Memory pressure handling
- Improved garbage collection

## Testing

The screensaver includes comprehensive error handling and recovery mechanisms:

- Network failure recovery
- Configuration validation
- Display error handling
- Automatic retry mechanisms

## Compatibility

- **macOS 10.15+** (Catalina and later)
- **All display types** (standard, wide, ultra-wide, vertical)
- **Multi-monitor setups**
- **MDM configuration** (compatible with existing deployments)

## Migration from Objective-C

The Swift implementation maintains 100% feature parity with the original Objective-C version while providing:

- Better performance and reliability
- Modern Swift language features
- Enhanced error handling
- Improved maintainability
- Future-proof architecture

## Troubleshooting

### Common Issues

1. **Screensaver not loading:**
   - Check configuration in System Preferences
   - Verify network connectivity
   - Check console logs for errors

2. **Display scaling issues:**
   - Ensure `zoomForFullScreen` is properly configured
   - Check display detection in logs

3. **Background effects not working:**
   - Verify `emptySpaceFillMode` configuration
   - Check image URLs for static backgrounds

### Debug Mode

Enable debug mode by setting `debugMode = true` in `PeopleScreensaverView.swift` for detailed logging.

## License

Copyright © 2020-2024 People.ai, Inc. All rights reserved.
