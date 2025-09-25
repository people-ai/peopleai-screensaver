# Multi-Version macOS Compatibility

This document outlines the compatibility features for the People.ai Screensaver across different macOS versions.

## Supported macOS Versions

- **macOS 10.15 (Catalina)** - Minimum supported version
- **macOS 11 (Big Sur)** - Full compatibility
- **macOS 12 (Monterey)** - Full compatibility  
- **macOS 13 (Ventura)** - Full compatibility
- **macOS 14 (Sonoma)** - Full compatibility
- **macOS 15 (Sequoia)** - Enhanced compatibility with additional features

## Version-Specific Features

### macOS 10.15+ (All Versions)
- Basic screensaver functionality
- WKWebView support
- Memory leak fixes
- Network timeout handling
- Error handling and recovery

### macOS 12+ (Monterey and later)
- Enhanced security settings
- Improved memory management
- Better network error handling
- Optimized image processing

### macOS 15+ (Sequoia and later)
- **Enhanced Security**: Stricter security policies
- **Background Process Prevention**: Prevents screensaver from running invisibly
- **Advanced Cleanup**: Enhanced garbage collection and memory management
- **Network Security**: Improved App Transport Security compliance

## Compatibility Matrix

| Feature | macOS 10.15+ | macOS 12+ | macOS 15+ |
|---------|---------------|-----------|-----------|
| Basic Screensaver | ✅ | ✅ | ✅ |
| WKWebView | ✅ | ✅ | ✅ |
| Memory Leak Fixes | ✅ | ✅ | ✅ |
| Network Timeouts | ✅ | ✅ | ✅ |
| Error Handling | ✅ | ✅ | ✅ |
| Enhanced Security | ❌ | ✅ | ✅ |
| Background Prevention | ❌ | ❌ | ✅ |
| Advanced Cleanup | ❌ | ❌ | ✅ |

## Code Implementation

### Availability Checks
The code uses `@available` checks to ensure compatibility:

```objc
// macOS 15+ specific features
if (@available(macOS 15.0, *)) {
    // Enhanced security and cleanup
} else if (@available(macOS 10.15, *)) {
    // Basic compatibility features
}
```

### Version-Specific Methods
- `handleMacOS15StopAnimation` - macOS 15+ specific cleanup
- `handleOlderMacOSStopAnimation` - macOS 10.15+ cleanup
- Enhanced WKWebView configuration based on version

## Build Instructions

### Multi-Version Build
Use the multi-version build script:

```bash
./build_multi_version.sh
```

This script:
- Detects the current macOS version
- Applies appropriate compatibility settings
- Builds with backward compatibility
- Validates the screensaver bundle

### Manual Build
For manual building, ensure:
- Deployment target: macOS 10.15
- SDK: Latest available
- Build settings: Compatible with target versions

## Installation Instructions

### macOS 13+ (System Settings)
1. Copy `People.ai.saver` to `~/Library/Screen Savers/`
2. Open **System Settings** > **Lock Screen** > **Screen Saver**
3. Select **People.ai** from the list

### macOS 12 and earlier (System Preferences)
1. Copy `People.ai.saver` to `~/Library/Screen Savers/`
2. Open **System Preferences** > **Desktop & Screen Saver**
3. Select **People.ai** from the list

## Testing Across Versions

### macOS 10.15 Testing
- Basic screensaver functionality
- WKWebView loading and rendering
- Memory management
- Network connectivity

### macOS 12 Testing
- Enhanced security features
- Improved error handling
- Better memory management
- Network timeout handling

### macOS 15 Testing
- Enhanced security compliance
- Background process prevention
- Advanced cleanup procedures
- Network security compliance

## Troubleshooting

### Common Issues by Version

#### macOS 10.15-11
- **Issue**: WKWebView not loading
- **Solution**: Check network permissions and firewall settings

#### macOS 12-14
- **Issue**: Security warnings
- **Solution**: Verify App Transport Security settings

#### macOS 15
- **Issue**: Background processes
- **Solution**: Ensure proper cleanup in stopAnimation

### Debugging Steps
1. Check Console.app for error messages
2. Verify screensaver installation
3. Test in System Settings/Preferences
4. Monitor memory usage
5. Check network connectivity

## Performance Considerations

### Memory Usage
- **macOS 10.15+**: Basic memory management
- **macOS 12+**: Enhanced memory optimization
- **macOS 15+**: Advanced memory cleanup

### Network Performance
- All versions: 30-second timeout
- All versions: Error handling and fallback
- All versions: Secure HTTPS connections

### Graphics Performance
- All versions: Automatic graphics switching support
- All versions: Optimized image processing
- All versions: Efficient blur operations

## Security Features

### Network Security
- App Transport Security compliance
- HTTPS-only connections
- Secure certificate validation

### Sandboxing
- Minimal required permissions
- Secure file access
- Protected memory usage

### Privacy
- No data collection
- Secure network communication
- Proper cleanup of sensitive data

## Future Compatibility

### Planned Support
- **macOS 16+**: Ready for future updates
- **Backward Compatibility**: Maintained for supported versions
- **Security Updates**: Regular compatibility updates

### Deprecation Policy
- **macOS 10.15**: Supported until further notice
- **Older Versions**: Not officially supported
- **New Versions**: Tested and supported as released

## Support and Maintenance

### Version Support
- **Current Version**: Full support
- **Previous Version**: Limited support
- **Older Versions**: Community support

### Update Policy
- Regular compatibility updates
- Security patches as needed
- Feature enhancements for supported versions

### Community Support
- GitHub issues for bug reports
- Documentation updates
- Compatibility testing feedback
