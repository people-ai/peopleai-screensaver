//
//  PeopleScreensaverView.swift
//  People.ai
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2022 People.ai, Inc. All rights reserved.
//  Optimized for performance and memory efficiency
//

import ScreenSaver
import WebKit
import AppKit
import CoreImage
import QuartzCore
import Combine
import os.log

// MARK: - Configuration Keys (Same as Objective-C version)
private let urlKey = "slidesUrl"
private let timeKey = "stayOnSlideTime"
private let resetKey = "resetSlidesWhenStarted"
private let currentSlideKey = "currentSlideKey"
private let maxSlidesKey = "maxSlides"
private let zoomFullScreenKey = "zoomForFullScreen"
private let viewRefreshTimeKey = "viewRefreshTime"
private let fillEmptySpaceKey = "fillEmptySpace"
private let dynamicKey = "dynamic"
private let emptySpaceFillImageKey = "emptySpaceFillImage"
private let emptySpaceFillModeKey = "emptySpaceFillMode"
private let debugModeEnabledKey = "debugModeEnabled"

private let configFile = "ai.people.screensaver"
private let modeMinimal = "minimal"
private let configError = "<html><body><b>Error while loading config file</b></body></html>"
private let noMoreSlidesError = "<html><body><b>No more slides</b></body></html>"

// MARK: - Performance Optimized Screensaver View
// @objc(PeopleScreensaverView) is required: without it, a plain Swift NSObject subclass is only
// visible to the Objective-C runtime under its module-qualified name, so Info.plist's
// NSPrincipalClass (a bare "PeopleScreensaverView" string) would resolve to nil via
// NSClassFromString and the screensaver would silently fail to load.
@objc(PeopleScreensaverView)
class PeopleScreensaverView: ScreenSaverView {
    
    // MARK: - Performance Logging
    private static let logger = OSLog(subsystem: "ai.people.screensaver", category: "performance")
    
    // MARK: - Architecture Optimization
    private static let isAppleSilicon: Bool = {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }()
    
    // MARK: - Core Properties
    private var webView: WKWebViewCustom?
    private var textView: NSTextView?
    private var imageView: NSImageView?
    
    // MARK: - WebView Lifecycle Management
    private var slidesDisplayedSinceLastTeardown: Int = 0
    private let teardownInterval: Int = 20
    private var cacheManager = CacheManager()
    private var preloadTask: Task<Void, Never>?
    
    // Force rebuild trigger - remove this comment after successful compilation
    
    // MARK: - Slide Management (Optimized)
    private var baseLink: String = ""
    private var currentSlide: Int = 0
    private var maxSlides: Int = 0
    private var slideTime: Int = 0
    private var slides: [String] = []
    
    // MARK: - Enhanced Caching System
    private var loadingSlides: Set<String> = []
    private var currentSlideIndex: Int = 0
    private var isFirstLoop: Bool = true
    
    // MARK: - Performance Optimized Timers
    private var instanceTimer: Timer?
    private var instanceAnimationTimer: Timer?
    private var instanceCurrentLink: String = ""
    private var refreshTimerInactiveStreak: Int = 0
    
    // MARK: - Display Optimization
    private var instanceResizeWidth: CGFloat = 0.05
    private var instanceResizeHeight: CGFloat = 0.05
    private var scalingApplied: Bool = false
    private var displayDetectionComplete: Bool = false
    
    // MARK: - Long-Running Stability
    private var lastScalingTime: Date = Date()
    private var scalingResetCount: Int = 0
    private var lastMemoryCleanup: Date = Date()
    private var runtimeHours: TimeInterval = 0
    private var periodicCleanupTimer: Timer?
    private var scalingResetTimer: Timer?
    
    // MARK: - Overscaling Prevention
    private var originalWebViewFrame: NSRect = .zero
    private var baseScalingApplied: Bool = false
    private var lastDisplayIdentifier: String = ""
    private var scalingValidationCount: Int = 0
    private var maxScalingAttempts: Int = 3
    
    // MARK: - Image Loading Retry
    private var slideLoadRetryCount: [String: Int] = [:]
    private var maxRetryAttempts: Int = 3

    // MARK: - Global Navigation Failure Tracking (network outage detection)
    private var consecutiveNavigationFailures: Int = 0
    private let maxConsecutiveNavigationFailures: Int = 3
    private var errorRecoveryTimer: Timer?
    private let errorRecoveryInterval: TimeInterval = 30.0
    
    // MARK: - Display-Specific Content Zoom
    private var displayContentZoomCache: [String: CGFloat] = [:]
    private var lastContentZoomDisplay: String = ""
    private var contentZoomApplied: Bool = false
    
    // MARK: - Zoom Prevention
    private var zoomPreventionEnabled: Bool = true
    private var maxContentZoom: CGFloat = 1.0
    private var minContentZoom: CGFloat = 1.0
    private var zoomLockApplied: Bool = false
    
    // MARK: - Resolution Independence
    private var currentBackingScaleFactor: CGFloat = 1.0
    private var displayResolutionCache: [String: (scale: CGFloat, resolution: NSSize)] = [:]
    private var graphicsContextConfigured: Bool = false
    
    // MARK: - Memory Management
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    // MARK: - Debug Mode
    private var debugInfoView: NSTextView?
    private var debugInfoTimer: Timer?
    
    // MARK: - Display Types
    private enum DisplayType {
        case builtIn
        case external
        case ultraWide
        case wide
        case vertical
        case standard
    }
    
    // MARK: - Static Configuration
    private static let mdmMode = true
    private static var debugMode = false
    private static var fillEmptySpace = false
    private static var dynamic = false
    private static var emptySpaceFillMode = ""
    private static var emptySpaceFillImage = ""
    
    private static let resizeWidth: CGFloat = 0.05
    private static let resizeHeight: CGFloat = 0.05
    private static let slideTransitionDuration: TimeInterval = 0.8
    
    private static var currentLink = ""
    private static var timer: Timer?
    private static var stayOnSlideTime: NSNumber?
    private static var animationTimer: Timer?
    private static var sharedContext: CIContext?
    
    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    override init(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)!
        setupScreensaver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScreensaver()
    }
    
    private func setupScreensaver() {
        setupWebView()
        setupNotifications()
        setupInitialState()
        setupMemoryManagement()
        setupPeriodicCleanup()
        setupResolutionIndependence()
        
        // Delayed initialization to prevent race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.performDelayedInitialization()
        }
    }
    
    private func performDelayedInitialization() {
        // CRITICAL: Reset scaling state before delayed initialization to prevent race conditions
        scalingApplied = false
        displayDetectionComplete = false
        baseScalingApplied = false
        lastDisplayIdentifier = ""
        
        // Ensure display detection is stable before proceeding
        guard let screen = getValidCurrentScreen() else {
            os_log("Delayed initialization failed - no valid screen detected", log: Self.logger, type: .error)
            return
        }
        
        let frame = screen.frame
        let aspectRatio = frame.size.width / frame.size.height
        let orientation = aspectRatio > 1.0 ? "Horizontal" : "Vertical"
        
        os_log("Delayed initialization successful: %{public}@ (%{public}@) - %.1fx%.1f (%.2f)", 
               log: Self.logger, type: .info, screen.localizedName, orientation, 
               frame.size.width, frame.size.height, aspectRatio)
        
        // CRITICAL: Apply proper scaling after delayed initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateWebViewForCurrentDisplay()
        }

        // MEMORY FIX: the live page load / MDM config load used to happen unconditionally here,
        // regardless of whether the screensaver was ever actually started. That let any instance
        // created but never animated (preview rows, orphaned display instances) load and
        // periodically reload a live WebKit page forever. That work now happens in
        // startAnimation() instead, gated the same way the rest of the background processes are.
    }
    
    // MARK: - Memory Management Setup
    private func setupMemoryManagement() {
        // DISABLED: Memory pressure monitoring causes background CPU usage
        // Only enable when screensaver is actually active
        // memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
        // memoryPressureSource?.setEventHandler { [weak self] in
        //     self?.handleMemoryPressure()
        // }
        // memoryPressureSource?.resume()
        
        // Setup periodic cleanup for long-running stability
        setupPeriodicCleanup()
        
        os_log("Memory pressure monitoring disabled to prevent background CPU usage", log: Self.logger, type: .info)
    }
    
    // MARK: - Long-Running Stability Management
    private func setupPeriodicCleanup() {
        // DISABLED: Periodic cleanup causes background CPU usage
        // Only enable if screensaver is actually running and visible
        // periodicCleanupTimer = Timer.scheduledTimer(withTimeInterval: 7200, repeats: true) { [weak self] _ in
        //     self?.performPeriodicCleanup()
        // }
        os_log("Periodic cleanup disabled to prevent background CPU usage", log: Self.logger, type: .info)
    }
    
    private func performPeriodicCleanup() {
        runtimeHours += 2.0
        lastMemoryCleanup = Date()
        
        os_log("Performing periodic cleanup after %f hours", log: Self.logger, type: .info, runtimeHours)
        
        // Reset scaling state to prevent drift
        resetScalingState()
        
        // Clean up accumulated memory
        cleanupMemoryIntensiveResources()
        
        // Clear WebView caches
        clearWebViewCaches()
        
        // Validate current display configuration
        validateDisplayConfiguration()
        
        os_log("Periodic cleanup completed", log: Self.logger, type: .info)
    }
    
    // MARK: - Scaling Reset (consolidated)
    // Periodic/dual-monitor/startup resets used to be three near-identical ~50-line functions.
    // They're merged here into one parameterized implementation; behavior at each of the three
    // call sites (displayConfigurationChanged, startAnimation, the scalingResetTimer) is unchanged.
    private func performScalingReset(
        context: String,
        checkScreensaverActive: Bool,
        clearDisplayResolutionCache: Bool,
        validateScreen: Bool,
        reapplyDelay: TimeInterval?,
        restoreDebugViewOnTop: Bool = false
    ) {
        if checkScreensaverActive {
            guard isScreensaverActive() else {
                os_log("%{public}@ scaling reset skipped - screensaver not active", log: Self.logger, type: .info, context)
                return
            }
        }

        os_log("%{public}@: Performing scaling reset", log: Self.logger, type: .info, context)

        scalingApplied = false
        displayDetectionComplete = false
        contentZoomApplied = false
        zoomLockApplied = false
        baseScalingApplied = false

        displayContentZoomCache.removeAll()
        lastContentZoomDisplay = ""
        if clearDisplayResolutionCache {
            displayResolutionCache.removeAll()
        }
        lastDisplayIdentifier = ""

        resetToOriginalFrame()

        if validateScreen {
            guard let screen = getValidCurrentScreen() else {
                os_log("%{public}@: No valid screen detected during reset", log: Self.logger, type: .error, context)
                return
            }

            let screenFrame = screen.frame
            let aspectRatio = screenFrame.size.width / screenFrame.size.height

            if aspectRatio < 0.1 || aspectRatio > 10.0 {
                os_log("%{public}@: Invalid aspect ratio %.2f during reset, using default scaling", log: Self.logger, type: .error, context, aspectRatio)
                applyDefaultScaling()
                return
            }

            if screenFrame.size.width < 100 || screenFrame.size.height < 100 {
                os_log("%{public}@: Screen too small %.0fx%.0f during reset, using default scaling", log: Self.logger, type: .error, context, screenFrame.size.width, screenFrame.size.height)
                applyDefaultScaling()
                return
            }

            os_log("%{public}@: Scaling reset completed successfully for %{public}@", log: Self.logger, type: .info, context, screen.localizedName)
        } else {
            os_log("%{public}@: Scaling reset completed", log: Self.logger, type: .info, context)
        }

        if let delay = reapplyDelay {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.updateWebViewForCurrentDisplay()
                if restoreDebugViewOnTop && Self.debugMode {
                    self.ensureDebugViewOnTop()
                }
            }
        }
    }

    private func performPeriodicScalingReset() {
        performScalingReset(context: "Periodic", checkScreensaverActive: true,
                             clearDisplayResolutionCache: false, validateScreen: false,
                             reapplyDelay: 0.5)
    }

    private func performDualMonitorScalingReset() {
        performScalingReset(context: "Dual monitor", checkScreensaverActive: false,
                             clearDisplayResolutionCache: true, validateScreen: true,
                             reapplyDelay: nil)
    }

    private func performStartupScalingReset() {
        performScalingReset(context: "Startup", checkScreensaverActive: false,
                             clearDisplayResolutionCache: true, validateScreen: true,
                             reapplyDelay: 0.1, restoreDebugViewOnTop: true)
    }
    
    private func resetScalingState() {
        scalingApplied = false
        displayDetectionComplete = false
        scalingResetCount += 1
        
        // Reset to default values
        instanceResizeWidth = 0.05
        instanceResizeHeight = 0.05
        
        os_log("Scaling state reset (count: %d)", log: Self.logger, type: .info, scalingResetCount)
    }
    
    private func clearWebViewCaches() {
        guard let webView = webView else { return }
        
        // Clear WebView caches safely
        webView.evaluateJavaScript("""
            if (window.caches) {
                window.caches.keys().then(function(names) {
                    return Promise.all(names.map(function(name) {
                        return window.caches.delete(name);
                    }));
                }));
            }
        """) { result, error in
            if let error = error {
                os_log("WebView cache cleanup failed: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
            } else {
                os_log("WebView caches cleared successfully", log: Self.logger, type: .info)
            }
        }
    }
    
    private func validateDisplayConfiguration() {
        // NOTE: content zoom is locked to 1.0 (calculateDisplaySpecificContentZoom) and instance
        // scaling doesn't drive layout (applyDefaultScaling/applyZoomPrevention use monitor bounds
        // directly), so there's no meaningful "expected vs current scaling" drift to detect here
        // (the removed calculateExpectedScaling() always returned a constant due to a clamp bug).
        // This just confirms the display is still valid.
        guard getValidCurrentScreen() != nil else {
            os_log("Display configuration validation failed - no valid screen", log: Self.logger, type: .error)
            return
        }
    }


    private func handleMemoryPressure() {
        os_log("Memory pressure detected, performing cleanup", log: Self.logger, type: .info)
        
        // Clear cache using Actor
        Task { [weak self] in
            await self?.cacheManager.clear()
        }
        
        // Force garbage collection
        DispatchQueue.global(qos: .background).async {
            // Trigger memory cleanup
            autoreleasepool {
                // Perform any memory-intensive operations here
            }
        }
    }
    
    private func cleanupMemoryIntensiveResources() {
        // Clear cache using Actor
        Task { [weak self] in
            await self?.cacheManager.clear()
        }
        loadingSlides.removeAll()
        
        // Clear WebView cache if needed with safe JavaScript execution
        if let webView = webView {
            webView.evaluateJavaScript("if (window.gc) { window.gc(); }") { result, error in
                if let error = error {
                    os_log("JavaScript GC cleanup failed: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Optimized WebView Setup
    private func setupWebView() {
        rebuildWebView()
    }
    
    // MARK: - WebView Lifecycle Management
    private func rebuildWebView() {
        // Clean up existing WebView if present
        if let existingWebView = webView {
            existingWebView.removeFromSuperview()
            existingWebView.navigationDelegate = nil
            existingWebView.stopLoading()
        }
        
        let config = WKWebViewConfiguration()
        
        // Performance optimizations
        config.setValue(NSNumber(value: false), forKey: "drawsBackground")
        config.suppressesIncrementalRendering = true
        
        // Shared process pool for better memory management
        config.processPool = WKProcessPool()
        
        // Optimized data store configuration
        let dataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = dataStore
        
        // Disable unnecessary features for performance
        config.allowsAirPlayForMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all
        
        // Enhanced performance settings for different macOS versions
        if #available(macOS 15.0, *) {
            let userContentController = WKUserContentController()
            config.userContentController = userContentController
            
            // Advanced performance optimizations for macOS 15+ (JavaScript enabled for screensaver functionality)
            config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
            config.preferences.setValue(false, forKey: "javaScriptCanOpenWindowsAutomatically")
            config.preferences.setValue(true, forKey: "javaScriptEnabled") // Enable JavaScript for screensaver
            config.preferences.setValue(false, forKey: "plugInsEnabled")
            
            // ARM64-specific WebView optimizations for stability
            if Self.isAppleSilicon {
                config.preferences.setValue(false, forKey: "allowFileAccessFromFileURLs")  // Disable for ARM64 stability
                config.preferences.setValue(false, forKey: "allowUniversalAccessFromFileURLs")
                os_log("ARM64 WebView: Using conservative settings for stability", log: Self.logger, type: .info)
            }
            
            // Add JavaScript error handling
            userContentController.add(self, name: "errorHandler")
        } else if #available(macOS 12.0, *) {
            // Optimizations for macOS 12+
            config.preferences.setValue(false, forKey: "javaScriptCanOpenWindowsAutomatically")
            config.preferences.setValue(false, forKey: "plugInsEnabled")
        }
        
        // Create optimized WebView with monitor bounds and ARM64 compatibility
        let monitorFrame = getMonitorBounds()
        webView = WKWebViewCustom(
            frame: monitorFrame,
            configuration: config
        )
        
        // ARM64-specific WebView setup for stability
        if Self.isAppleSilicon {
            webView?.setValue(false, forKey: "drawsBackground")
            webView?.setValue(false, forKey: "drawsTransparentBackground")
            os_log("ARM64 WebView: Applied stability settings", log: Self.logger, type: .info)
        }
        
        // Add JavaScript error handling script
        if #available(macOS 15.0, *) {
            let errorScript = """
            window.onerror = function(message, source, lineno, colno, error) {
                window.webkit.messageHandlers.errorHandler.postMessage({
                    message: message,
                    source: source,
                    line: lineno,
                    column: colno,
                    error: error ? error.toString() : 'Unknown error'
                });
            };
            """
            let script = WKUserScript(source: errorScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(script)
        }
        
        // Add zoom prevention script
        let zoomPreventionScript = """
        // ZOOM PREVENTION: Add viewport meta tag to prevent zoom
        const viewport = document.querySelector('meta[name="viewport"]');
        if (viewport) {
            viewport.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
        } else {
            const meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.head.appendChild(meta);
        }
        
        // Prevent zoom via CSS
        document.body.style.zoom = '1.0';
        document.documentElement.style.zoom = '1.0';
        document.body.style.transform = 'scale(1.0)';
        document.documentElement.style.transform = 'scale(1.0)';
        """
        let zoomScript = WKUserScript(source: zoomPreventionScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(zoomScript)
        
        guard let webView = webView else { return }
        
        // Performance-optimized layer setup
        webView.wantsLayer = true
        webView.layer?.contentsGravity = .resizeAspectFill
        
        // CRITICAL: Ensure content is centered and properly positioned
        webView.layer?.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        webView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // FIXED: WebView sized to monitor bounds, no autoresizing needed
        addSubview(webView)
        // Remove autoresizing to prevent cumulative scaling
        autoresizingMask = []
        autoresizesSubviews = false
        webView.autoresizingMask = []
        
        // Ensure WebView fills the entire monitor
        webView.frame = monitorFrame
        
        // Enable hardware acceleration
        webView.layer?.drawsAsynchronously = true
        
        if Self.debugMode {
            setupDebugView()
        }
        
        os_log("WebView rebuilt with performance optimizations", log: Self.logger, type: .info)
    }
    
    // MARK: - WebView Teardown Cycle
    private func performWebViewTeardown() {
        os_log("Performing WebView teardown after %d slides", log: Self.logger, type: .info, slidesDisplayedSinceLastTeardown)
        
        // Stop all WebView activity
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        
        // Remove from view hierarchy
        webView?.removeFromSuperview()
        
        // Clear WebView reference to deallocate and release WebKit.WebContent process
        webView = nil
        
        // Force garbage collection
        DispatchQueue.global(qos: .background).async {
            autoreleasepool {
                // Force memory cleanup
            }
        }
        
        // Rebuild WebView with fresh instance
        rebuildWebView()
        
        // Reset counter
        slidesDisplayedSinceLastTeardown = 0
        
        os_log("WebView teardown completed, fresh instance created", log: Self.logger, type: .info)
    }
    
    private func checkForTeardownCycle() {
        slidesDisplayedSinceLastTeardown += 1
        
        if slidesDisplayedSinceLastTeardown >= teardownInterval {
            performWebViewTeardown()
        }
    }
    
    private func setupDebugView() {
        textView = NSTextView(frame: CGRect(x: 0, y: 0, width: 500, height: 300))
        guard let textView = textView else { return }
        
        addSubview(textView)
        textView.textColor = .red
        textView.backgroundColor = .white
        showDebugMessage("initial parent view rect: \(frame)")
        showDebugMessage("initial web view rect: \(webView?.frame ?? .zero)")
    }
    
    // MARK: - Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func displayConfigurationChanged(_ notification: Notification) {
        // CRITICAL: Only process display changes if screensaver is active
        guard isScreensaverActive() else {
            os_log("Display change ignored - screensaver not active", log: Self.logger, type: .info)
            return
        }
        
        let currentDisplayId = getDisplayIdentifier()
        
        // Enhanced display change detection with orientation validation
        let displayActuallyChanged = lastDisplayIdentifier != currentDisplayId
        let orientationChanged = !validateCurrentOrientation()
        
        if !displayActuallyChanged && !orientationChanged {
            os_log("Display configuration change detected but display and orientation unchanged, skipping", log: Self.logger, type: .info)
            return
        }
        
        DispatchQueue.main.async {
            if displayActuallyChanged {
                os_log("Dual monitor: Display configuration changed from %{public}@ to %{public}@", log: Self.logger, type: .info, self.lastDisplayIdentifier, currentDisplayId)
            } else {
                os_log("Dual monitor: Display orientation changed, forcing update", log: Self.logger, type: .info)
            }
            
            // Reset all scaling state for new display or orientation
            self.scalingApplied = false
            self.displayDetectionComplete = false
            self.scalingValidationCount = 0
            self.baseScalingApplied = false
            
            // Reset content zoom state for new display
            self.contentZoomApplied = false
            self.lastContentZoomDisplay = ""
            
            // Reset resolution independence state
            self.graphicsContextConfigured = false
            self.currentBackingScaleFactor = 1.0
            
            // Reset to original frame before applying new scaling
            self.resetToOriginalFrame()
            
            // Clear cached display identifier to force fresh detection
            self.lastDisplayIdentifier = ""
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Increased delay for stability
                // CRITICAL: Dual monitor specific scaling reset
                self.performDualMonitorScalingReset()
                self.updateWebViewForCurrentDisplay()
                
                if Self.debugMode {
                    self.showDebugMessage("Dual monitor: Display configuration changed - updating layout")
                    self.showDebugMessage(self.getCurrentDisplayInfo())
                }
            }
        }
    }
    
    // MARK: - Initial State
    private func setupInitialState() {
        loadingSlides = []
        currentSlideIndex = 0
        isFirstLoop = true
        instanceCurrentLink = ""
        
        // Reset all display-related state to prevent confusion
        instanceResizeWidth = 0.05
        instanceResizeHeight = 0.05
        scalingApplied = false
        displayDetectionComplete = false
        baseScalingApplied = false
        lastDisplayIdentifier = ""
        scalingValidationCount = 0
        scalingResetCount = 0
        lastScalingTime = Date()
        originalWebViewFrame = .zero
        
        // Reset content zoom state
        contentZoomApplied = false
        lastContentZoomDisplay = ""
        
        // Reset resolution independence state
        graphicsContextConfigured = false
        currentBackingScaleFactor = 1.0
        displayResolutionCache.removeAll()
        
        // Clear any cached retry counts
        slideLoadRetryCount.removeAll()
        refreshTimerInactiveStreak = 0

        os_log("Initial state reset completed", log: Self.logger, type: .info)
    }
    
    // MARK: - Frame Updates
    func setFrame(_ frameRect: NSRect) {
        frame = frameRect
        
        // FIXED: Ensure WebView fits the monitor bounds, not parent bounds
        let monitorFrame = getMonitorBounds()
        webView?.frame = monitorFrame
        
        // CRITICAL: Reset scaling state before updating to prevent persistent zoom issues
        if !scalingApplied {
            scalingApplied = false
            displayDetectionComplete = false
            baseScalingApplied = false
            lastDisplayIdentifier = ""
        }
        
        updateWebViewForCurrentDisplay()
        
        if Self.debugMode {
            showDebugMessage("setFrame parent view rect: \(frame)")
            showDebugMessage("setFrame web view rect: \(webView?.frame ?? .zero)")
            showDebugMessage("setFrame monitor bounds: \(monitorFrame)")
            showDebugMessage("Current display: \(getCurrentDisplayInfo())")
        }
    }
    
    // MARK: - Monitor Bounds Helper
    private func getMonitorBounds() -> NSRect {
        guard let screen = getValidCurrentScreen() else {
            // Fallback to parent bounds if no screen detected
            os_log("No valid screen detected, using parent bounds as fallback", log: Self.logger, type: .error)
            return bounds
        }
        
        let screenFrame = screen.frame
        // Return monitor bounds starting from origin (0,0) with screen dimensions
        let monitorFrame = NSRect(
            x: 0,
            y: 0,
            width: screenFrame.size.width,
            height: screenFrame.size.height
        )
        
        os_log("Monitor bounds: %{public}@ (screen: %{public}@)", log: Self.logger, type: .info, monitorFrame.debugDescription, screenFrame.debugDescription)
        return monitorFrame
    }
    
    // MARK: - Display Management
    private func updateWebViewForCurrentDisplay() {
        let currentDisplayId = getDisplayIdentifier()
        
        // Enhanced display change detection with orientation validation
        if lastDisplayIdentifier == currentDisplayId && scalingApplied {
            let timeSinceLastScaling = Date().timeIntervalSince(lastScalingTime)
            
            // Validate current orientation is still correct
            if validateCurrentOrientation() {
                // Only allow rescaling if significant time has passed or display changed
                if timeSinceLastScaling < 10.0 {
                    os_log("Scaling already applied for current display with valid orientation, skipping to prevent cumulative effects", log: Self.logger, type: .info)
                    return
                }
            } else {
                os_log("Orientation validation failed, forcing display update", log: Self.logger, type: .info)
                // Force update by resetting state
                scalingApplied = false
                displayDetectionComplete = false
            }
        }
        
        // Validate scaling attempts
        if scalingValidationCount >= maxScalingAttempts {
            os_log("Maximum scaling attempts reached, using default scaling", log: Self.logger, type: .error)
            applyDefaultScaling()
            return
        }
        
        // Reset to original frame before applying new scaling
        if baseScalingApplied {
            resetToOriginalFrame()
        }
        
        let moduleName = Bundle(for: type(of: self)).bundleIdentifier ?? ""
        let defaults = UserDefaults(suiteName: moduleName)
        let zoom = defaults?.object(forKey: zoomFullScreenKey) as? NSNumber
        
        if bounds.size.width <= 0 || bounds.size.height <= 0 {
            print("People.AI invalid bounds, skipping scaling: \(bounds)")
            return
        }
        
        guard let currentScreen = getValidCurrentScreen() else {
            print("People.AI no valid screen detected, using default scaling")
            applyDefaultScaling()
            return
        }
        
        let screenFrame = currentScreen.frame
        if screenFrame.size.width <= 0 || screenFrame.size.height <= 0 {
            print("People.AI invalid screen dimensions, using default scaling")
            applyDefaultScaling()
            return
        }
        
        let aspectRatio = screenFrame.size.width / screenFrame.size.height
        
        if zoom?.boolValue == true {
            applyValidatedScaling()

            if Self.debugMode {
                showDebugMessage("Zoom scaling applied (locked to monitor bounds), aspect=\(aspectRatio)")
            }
        } else {
            applyDefaultScaling()
        }
        
        // Store original frame for future resets
        if !baseScalingApplied {
            originalWebViewFrame = webView?.frame ?? bounds
            baseScalingApplied = true
        }
        
        scalingApplied = true
        displayDetectionComplete = true
        lastScalingTime = Date()
        lastDisplayIdentifier = currentDisplayId
        scalingValidationCount += 1
        
        // Apply display-specific content zoom
        applyDisplaySpecificContentZoom()
        
        // Update graphics context for resolution independence
        updateGraphicsContextForCurrentDisplay()
        
        os_log("Scaling applied successfully at %{public}@ for display %{public}@", log: Self.logger, type: .info, lastScalingTime.description, currentDisplayId)
    }
    
    private func getCurrentDisplayInfo() -> String {
        let currentScreen = window?.screen ?? NSScreen.main
        let screenFrame = currentScreen?.frame ?? .zero
        let aspectRatio = screenFrame.size.width / screenFrame.size.height
        let orientation = aspectRatio > 1.0 ? "Horizontal" : "Vertical"
        
        var displayType = ""
        if aspectRatio > 2.0 {
            displayType = " [ULTRA-WIDE]"
        } else if aspectRatio > 1.5 {
            displayType = " [WIDE]"
        }
        
        return "\(currentScreen?.localizedName ?? "Unknown Display") (\(orientation)) - \(screenFrame.size)\(displayType)"
    }
    
    private func getValidCurrentScreen() -> NSScreen? {
        // Enhanced screen detection with dual monitor validation and retry logic
        var detectedScreen: NSScreen?
        var detectionMethod = ""
        
        // First try: Get screen from window (most accurate for screensaver)
        if let window = window, let screen = window.screen {
            let screenFrame = screen.frame
            if screenFrame.size.width > 0 && screenFrame.size.height > 0 {
                // Validate that this is actually the screensaver's display
                if isValidScreensaverDisplay(screen) {
                    detectedScreen = screen
                    detectionMethod = "window_screen"
                    os_log("Dual monitor: Using window screen %{public}@", log: Self.logger, type: .info, screen.localizedName)
                }
            }
        }
        
        // Second try: Find screen that matches our bounds (if window screen failed)
        if detectedScreen == nil {
            let currentBounds = bounds
            if currentBounds.size.width > 0 && currentBounds.size.height > 0 {
                for screen in NSScreen.screens {
                    let screenFrame = screen.frame
                    if screenFrame.size.width > 0 && screenFrame.size.height > 0 {
                        // Check if this screen contains our bounds or matches our size
                        if screenFrame.contains(currentBounds) || 
                           (abs(screenFrame.size.width - currentBounds.size.width) < 10 && 
                            abs(screenFrame.size.height - currentBounds.size.height) < 10) {
                            if isValidScreensaverDisplay(screen) {
                                detectedScreen = screen
                                detectionMethod = "bounds_match"
                                break
                            }
                        }
                    }
                }
            }
        }
        
        // Third try: Get primary screen (fallback)
        if detectedScreen == nil {
            let primaryScreen = NSScreen.screens.first { screen in
                let frame = screen.frame
                return frame.size.width > 0 && frame.size.height > 0 && isValidScreensaverDisplay(screen)
            }
            
            if let primaryScreen = primaryScreen {
                detectedScreen = primaryScreen
                detectionMethod = "primary_screen"
            }
        }
        
        // Fourth try: Main screen (last resort)
        if detectedScreen == nil {
            let mainScreen = NSScreen.main
            let screenFrame = mainScreen?.frame ?? .zero
            if screenFrame.size.width > 0 && screenFrame.size.height > 0 {
                detectedScreen = mainScreen
                detectionMethod = "main_screen"
            }
        }
        
        if let screen = detectedScreen {
            let frame = screen.frame
            let aspectRatio = frame.size.width / frame.size.height
            let orientation = aspectRatio > 1.0 ? "Horizontal" : "Vertical"
            // CRITICAL: Dual monitor validation - ensure screen is stable
            if aspectRatio < 0.1 || aspectRatio > 10.0 {
                os_log("Dual monitor: Invalid aspect ratio %.2f for screen %{public}@, forcing reset", log: Self.logger, type: .error, aspectRatio, screen.localizedName)
                return nil
            }
            
            // Validate screen is not too small (common issue in dual monitor)
            if frame.size.width < 100 || frame.size.height < 100 {
                os_log("Dual monitor: Screen too small %.0fx%.0f for %{public}@, forcing reset", log: Self.logger, type: .error, frame.size.width, frame.size.height, screen.localizedName)
                return nil
            }
            
            os_log("Dual monitor: Screen detected via %{public}@: %{public}@ (%{public}@) - %.1fx%.1f (%.2f)", 
                   log: Self.logger, type: .info, detectionMethod, screen.localizedName, orientation, 
                   frame.size.width, frame.size.height, aspectRatio)
            return screen
        }
        
        os_log("No valid screen detected", log: Self.logger, type: .error)
        return nil
    }
    
    private func isValidScreensaverDisplay(_ screen: NSScreen) -> Bool {
        let frame = screen.frame
        let aspectRatio = frame.size.width / frame.size.height
        
        // Validate reasonable display dimensions
        guard frame.size.width > 100 && frame.size.height > 100 else { return false }
        
        // Validate reasonable aspect ratio (not too extreme)
        guard aspectRatio > 0.1 && aspectRatio < 10.0 else { return false }
        
        // Additional validation: check if screen is actually visible and active
        guard !frame.isEmpty else { return false }
        
        return true
    }
    
    private func validateCurrentOrientation() -> Bool {
        guard let screen = getValidCurrentScreen() else { return false }
        
        let frame = screen.frame
        let currentAspectRatio = frame.size.width / frame.size.height
        let currentOrientation = currentAspectRatio > 1.0
        
        // Get the expected orientation from our current scaling settings
        let expectedOrientation = instanceResizeWidth > instanceResizeHeight
        
        // Allow some tolerance for aspect ratio calculations
        let _: CGFloat = 0.1
        
        // Check if orientation matches expectations
        let orientationMatches = currentOrientation == expectedOrientation
        
        // Additional validation: check if aspect ratio is reasonable
        let aspectRatioValid = currentAspectRatio > 0.1 && currentAspectRatio < 10.0
        
        os_log("Orientation validation: current=%.2f (%.1f), expected=%.1f, matches=%@, valid=%@", 
               log: Self.logger, type: .info, currentAspectRatio, currentOrientation ? 1.0 : 0.0, 
               expectedOrientation ? 1.0 : 0.0, orientationMatches ? "YES" : "NO", aspectRatioValid ? "YES" : "NO")
        
        return orientationMatches && aspectRatioValid
    }
    
    private func getDisplayIdentifier() -> String {
        guard let screen = getValidCurrentScreen() else { return "unknown" }
        let frame = screen.frame
        let aspectRatio = frame.size.width / frame.size.height
        let orientation = aspectRatio > 1.0 ? "H" : "V"
        return "\(screen.localizedName)_\(Int(frame.size.width))x\(Int(frame.size.height))_\(orientation)_\(String(format: "%.2f", aspectRatio))"
    }
    
    // MARK: - Display-Specific Content Zoom
    private func getDisplayType(_ screen: NSScreen) -> DisplayType {
        let frame = screen.frame
        let aspectRatio = frame.size.width / frame.size.height
        
        // Detect if this is a built-in display (usually has specific characteristics)
        let isBuiltIn = screen.localizedName.contains("Built-in") || 
                       screen.localizedName.contains("MacBook") ||
                       screen.localizedName.contains("Retina")
        
        if isBuiltIn {
            if aspectRatio > 2.0 {
                return .ultraWide
            } else if aspectRatio > 1.5 {
                return .wide
            } else if aspectRatio < 0.7 {
                return .vertical
            } else {
                return .standard
            }
        } else {
            // External display
            if aspectRatio > 2.0 {
                return .ultraWide
            } else if aspectRatio > 1.5 {
                return .wide
            } else if aspectRatio < 0.7 {
                return .vertical
            } else {
                return .standard
            }
        }
    }
    
    private func calculateDisplaySpecificContentZoom(for screen: NSScreen) -> CGFloat {
        // ZOOM PREVENTION: Always return 1.0 to prevent any zoom/overscaling
        let contentZoom: CGFloat = 1.0
        
        os_log("ZOOM PREVENTION: Content zoom locked at 1.0 to prevent overscaling", log: Self.logger, type: .info)
        
        return contentZoom
    }
    
    private func applyDisplaySpecificContentZoom() {
        guard getValidCurrentScreen() != nil else { 
            os_log("No valid screen for content zoom application", log: Self.logger, type: .error)
            return 
        }
        
        let currentDisplayId = getDisplayIdentifier()
        
        // Check if content zoom is already applied for this display
        if lastContentZoomDisplay == currentDisplayId && contentZoomApplied {
            os_log("Content zoom already applied for display %{public}@", log: Self.logger, type: .info, currentDisplayId)
            return
        }
        
        // ZOOM PREVENTION: Lock content zoom at 1.0 to prevent overscaling
        let contentZoom: CGFloat = 1.0
        
        // Apply zoom prevention via CSS
        let zoomPreventionScript = """
        // ZOOM PREVENTION: Lock zoom at 1.0 to prevent overscaling
        document.body.style.zoom = '1.0';
        document.documentElement.style.zoom = '1.0';
        document.body.style.transform = 'scale(1.0)';
        document.documentElement.style.transform = 'scale(1.0)';
        
        // Prevent user zoom
        document.addEventListener('wheel', function(e) {
            if (e.ctrlKey) {
                e.preventDefault();
            }
        }, { passive: false });
        
        // Prevent pinch zoom
        document.addEventListener('gesturestart', function(e) {
            e.preventDefault();
        }, { passive: false });
        
        document.addEventListener('gesturechange', function(e) {
            e.preventDefault();
        }, { passive: false });
        
        document.addEventListener('gestureend', function(e) {
            e.preventDefault();
        }, { passive: false });
        """
        
        webView?.evaluateJavaScript(zoomPreventionScript) { result, error in
            if let error = error {
                os_log("Failed to apply zoom prevention: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
            } else {
                self.contentZoomApplied = true
                self.lastContentZoomDisplay = currentDisplayId
                self.displayContentZoomCache[currentDisplayId] = contentZoom
                self.zoomLockApplied = true
                os_log("ZOOM PREVENTION: Content zoom locked at 1.0 to prevent overscaling", log: Self.logger, type: .info)
            }
        }
    }
    
    private func getCachedContentZoom(for displayId: String) -> CGFloat? {
        return displayContentZoomCache[displayId]
    }
    
    private func setCachedContentZoom(_ zoom: CGFloat, for displayId: String) {
        displayContentZoomCache[displayId] = zoom
    }
    
    // MARK: - Resolution Independence Setup
    private func setupResolutionIndependence() {
        // Configure for resolution independence
        wantsLayer = true
        layer?.contentsGravity = .resizeAspectFill
        
        // Enable high-resolution rendering
        if let layer = layer {
            layer.contentsScale = 1.0 // Will be updated based on display
            layer.drawsAsynchronously = true
        }
        
        os_log("Resolution independence setup completed", log: Self.logger, type: .info)
    }
    
    private func updateGraphicsContextForCurrentDisplay() {
        guard let screen = getValidCurrentScreen() else { return }
        
        let backingScaleFactor = screen.backingScaleFactor
        let displayId = getDisplayIdentifier()
        
        // Update current backing scale factor
        currentBackingScaleFactor = backingScaleFactor
        
        // Cache display resolution information
        let resolution = screen.frame.size
        displayResolutionCache[displayId] = (scale: backingScaleFactor, resolution: resolution)
        
        // Configure graphics context for current display
        configureGraphicsContextForDisplay(screen)
        
        // Update WebView for high-resolution display
        updateWebViewForHighResolutionDisplay(screen)
        
        os_log("Graphics context updated for display %{public}@: scale=%.1f, resolution=%.0fx%.0f", 
               log: Self.logger, type: .info, screen.localizedName, backingScaleFactor, resolution.width, resolution.height)
    }
    
    private func configureGraphicsContextForDisplay(_ screen: NSScreen) {
        let backingScaleFactor = screen.backingScaleFactor
        
        // Configure layer for high-resolution display
        if let layer = layer {
            layer.contentsScale = backingScaleFactor
            layer.drawsAsynchronously = true
            
            // Enable high-resolution rendering
            if backingScaleFactor > 1.0 {
                layer.shouldRasterize = false // Disable rasterization for Retina displays
                layer.rasterizationScale = backingScaleFactor
            }
        }
        
        // Configure view for resolution independence
        wantsLayer = true
        
        // CRITICAL: Keep autoresizing disabled for dual monitor stability
        // Do NOT re-enable autoresizing as it causes cumulative scaling in dual monitor setups
        autoresizingMask = []
        autoresizesSubviews = false
        
        graphicsContextConfigured = true
    }
    
    private func updateWebViewForHighResolutionDisplay(_ screen: NSScreen) {
        guard let webView = webView else { return }
        
        let backingScaleFactor = screen.backingScaleFactor
        
        // Configure WebView for high-resolution display
        webView.wantsLayer = true
        if let webViewLayer = webView.layer {
            webViewLayer.contentsScale = backingScaleFactor
            webViewLayer.drawsAsynchronously = true
            
            // Enable high-resolution rendering for WebView
            if backingScaleFactor > 1.0 {
                webViewLayer.shouldRasterize = false
                webViewLayer.rasterizationScale = backingScaleFactor
            }
        }
        
        // FIXED: Use consistent monitor bounds for high-resolution display
        let monitorFrame = getMonitorBounds()
        webView.frame = monitorFrame
        
        os_log("WebView updated for high-resolution display: scale=%.1f, frame=%@", 
               log: Self.logger, type: .info, backingScaleFactor, monitorFrame.debugDescription)
    }
    
    private func getDisplayResolutionInfo() -> (scale: CGFloat, resolution: NSSize, isRetina: Bool) {
        guard let screen = getValidCurrentScreen() else {
            return (scale: 1.0, resolution: NSSize.zero, isRetina: false)
        }
        
        let backingScaleFactor = screen.backingScaleFactor
        let resolution = screen.frame.size
        let isRetina = backingScaleFactor > 1.0
        
        return (scale: backingScaleFactor, resolution: resolution, isRetina: isRetina)
    }
    
    private func resetToOriginalFrame() {
        guard let webView = webView else { return }
        
        // FIXED: Reset to monitor bounds to prevent cumulative scaling
        let monitorFrame = getMonitorBounds()
        webView.frame = monitorFrame
        os_log("Reset WebView to monitor frame: %{public}@", log: Self.logger, type: .info, monitorFrame.debugDescription)
    }
    
    private func applyValidatedScaling() {
        // ZOOM PREVENTION: Use default scaling and prevent overscaling
        os_log("ZOOM PREVENTION: Using default scaling to prevent overscaling", log: Self.logger, type: .info)
        applyDefaultScaling()
        
        // Apply additional zoom prevention
        applyZoomPrevention()
    }
    
    private func applyZoomPrevention() {
        // ZOOM PREVENTION: Lock WebView scaling to prevent overscaling
        guard let webView = webView else { return }
        
        // FIXED: Reset to monitor bounds to prevent any scaling
        let monitorFrame = getMonitorBounds()
        webView.frame = monitorFrame
        
        // Apply zoom prevention via JavaScript
        let zoomPreventionScript = """
        // ZOOM PREVENTION: Lock all zoom and scaling
        document.body.style.zoom = '1.0';
        document.documentElement.style.zoom = '1.0';
        document.body.style.transform = 'scale(1.0)';
        document.documentElement.style.transform = 'scale(1.0)';
        document.body.style.maxZoom = '1.0';
        document.documentElement.style.maxZoom = '1.0';
        
        // Prevent any scaling
        document.body.style.overflow = 'hidden';
        document.documentElement.style.overflow = 'hidden';
        
        // CRITICAL: Ensure content is properly centered and positioned
        document.body.style.margin = '0';
        document.body.style.padding = '0';
        document.body.style.position = 'relative';
        document.body.style.left = '0';
        document.body.style.top = '0';
        document.body.style.width = '100%';
        document.body.style.height = '100%';
        
        // Center content properly
        document.body.style.display = 'flex';
        document.body.style.alignItems = 'center';
        document.body.style.justifyContent = 'center';
        """
        
        webView.evaluateJavaScript(zoomPreventionScript) { result, error in
            if let error = error {
                os_log("Zoom prevention failed: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
            } else {
                os_log("ZOOM PREVENTION: WebView scaling locked to prevent overscaling", log: Self.logger, type: .info)
            }
        }
    }
    
    private func applyDefaultScaling() {
        // FIXED: Use monitor bounds instead of parent bounds
        let monitorFrame = getMonitorBounds()
        webView?.frame = monitorFrame
        
        print("People.AI applied default scaling: monitorFrame=\(monitorFrame)")
    }
    
    // MARK: - Animation Lifecycle
    override func startAnimation() {
        super.startAnimation()
        
        // CRITICAL: Check if we should actually start (prevent background activity)
        guard !isHidden && window != nil else {
            os_log("Preventing background animation start", log: Self.logger, type: .info)
            return
        }
        
        // CRITICAL: Reset scaling state at startup to prevent persistent zoom issues
        performStartupScalingReset()

        // Enable background processes only when screensaver is actually active
        enableBackgroundProcesses()

        // MEMORY FIX: heavy content load moved here from init/performDelayedInitialization so
        // instances that are created but never started (preview rows, orphaned display
        // instances) never touch the network or schedule a reload timer.
        if isPreview {
            loadPreviewPlaceholder()
        } else if Self.mdmMode {
            loadMdm()
            checkViewRefreshTime()
            animationTimeInterval = 1.0
        }
    }

    private func loadPreviewPlaceholder() {
        // Static, non-networked content for picker/preview thumbnails — no live Slides autoplay,
        // no refresh timer, so preview rows can't leak memory in the background.
        webView?.loadHTMLString(
            "<html><body style=\"margin:0;background:#ffffff;display:flex;align-items:center;justify-content:center;font-family:-apple-system,sans-serif;color:#666;\"><b>People.ai Screensaver</b></body></html>",
            baseURL: nil
        )
        os_log("Preview instance: loaded static placeholder, skipping live MDM load", log: Self.logger, type: .info)
    }

    // MARK: - Background Process Management
    private func isScreensaverActive() -> Bool {
        // Check if screensaver is actually running and visible
        return !isHidden && window != nil && isAnimating && superview != nil
    }
    
    private func enableBackgroundProcesses() {
        // Only enable if screensaver is actually active
        guard isScreensaverActive() else {
            os_log("Screensaver not active, skipping background process enablement", log: Self.logger, type: .info)
            return
        }
        
        // Only enable memory monitoring when screensaver is active
        if memoryPressureSource == nil {
            memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
            memoryPressureSource?.setEventHandler { [weak self] in
                self?.handleMemoryPressure()
            }
            memoryPressureSource?.resume()
        }
        
        // Only enable periodic cleanup when screensaver is active
        if periodicCleanupTimer == nil {
            periodicCleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
                self?.performPeriodicCleanup()
            }
        }
        
        // CRITICAL: Add periodic scaling reset to prevent cumulative scaling
        if scalingResetTimer == nil {
            scalingResetTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
                self?.performPeriodicScalingReset()
            }
        }
        
        os_log("Background processes enabled for active screensaver", log: Self.logger, type: .info)
    }
    
    private func disableBackgroundProcesses() {
        // Disable memory monitoring
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        
        // Disable periodic cleanup
        periodicCleanupTimer?.invalidate()
        periodicCleanupTimer = nil
        
        // Disable scaling reset timer
        scalingResetTimer?.invalidate()
        scalingResetTimer = nil
        
        os_log("Background processes disabled to prevent CPU usage", log: Self.logger, type: .info)
    }
    
    // MARK: - Comprehensive WebView Cleanup
    private func stopWebViewActivity() {
        guard let webView = webView else { return }
        
        // Stop all WebView activity immediately
        webView.stopLoading()
        webView.navigationDelegate = nil
        
        // Stop JavaScript execution
        webView.evaluateJavaScript("window.stop();") { _, error in
            if let error = error {
                os_log("Failed to stop JavaScript: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
            }
        }
        
        // Clear WebView content
        webView.loadHTMLString("", baseURL: nil)
        
        os_log("WebView activity stopped", log: Self.logger, type: .info)
    }
    
    private func cleanupWebViewCompletely() {
        guard let webView = webView else { return }
        
        // Remove from superview
        webView.removeFromSuperview()
        
        // Clear all WebView data
        if #available(macOS 10.15, *) {
            let dataStore = webView.configuration.websiteDataStore
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0)) {
                os_log("WebView data cleared", log: Self.logger, type: .info)
            }
        }
        
        // Clear WebView reference
        self.webView = nil
        
        os_log("WebView completely cleaned up", log: Self.logger, type: .info)
    }
    
    override func stopAnimation() {
        super.stopAnimation()
        
        os_log("Stopping animation with comprehensive cleanup", log: Self.logger, type: .info)
        
        // CRITICAL: Stop all WebView activity immediately
        stopWebViewActivity()
        
        // Invalidate timers immediately
        instanceTimer?.invalidate()
        instanceTimer = nil
        instanceAnimationTimer?.invalidate()
        instanceAnimationTimer = nil
        errorRecoveryTimer?.invalidate()
        errorRecoveryTimer = nil

        // Disable all background processes
        disableBackgroundProcesses()
        
        // Remove observers
        NotificationCenter.default.removeObserver(self)
        
        // Clean up WebView completely
        cleanupWebViewCompletely()
        
        // Enhanced cleanup for different macOS versions
        if #available(macOS 15.0, *) {
            handleMacOS15StopAnimation()
        } else if #available(macOS 10.15, *) {
            handleOlderMacOSStopAnimation()
        }
        
        // CRITICAL: Stop static animation timer
        Self.animationTimer?.invalidate()
        Self.animationTimer = nil
        
        // CRITICAL: Cancel all network requests
        cancelAllNetworkRequests()
        
        // CRITICAL: Clear all caches and memory
        performCompleteCleanup()
        
        // CRITICAL: Force memory cleanup
        forceMemoryCleanup()
        
        // CRITICAL: Reset all state variables
        resetAllStateVariables()
        
        // Clean up debug mode
        cleanupDebugMode()
        
        os_log("Animation stopped with complete cleanup", log: Self.logger, type: .info)
    }
    
    private func handleMacOS15StopAnimation() {
        if #available(macOS 15.0, *) {
            webView?.evaluateJavaScript("window.stop();") { result, error in
                if let error = error {
                    os_log("JavaScript stop failed: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
                }
            }
            webView?.loadHTMLString("", baseURL: nil)
            webView?.evaluateJavaScript("if (window.gc) { window.gc(); }") { result, error in
                if let error = error {
                    os_log("JavaScript GC failed: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    private func handleOlderMacOSStopAnimation() {
        if #available(macOS 10.15, *) {
            webView?.loadHTMLString("", baseURL: nil)
            webView?.evaluateJavaScript("window.stop();") { result, error in
                if let error = error {
                    os_log("JavaScript stop failed: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Animation Frame
    override func animateOneFrame() {
        // CRITICAL: Prevent background activity
        guard isScreensaverActive() else {
            os_log("Preventing background animation frame - screensaver not active", log: Self.logger, type: .info)
            return
        }
        
        if Self.mdmMode {
            saveCurrentSlide()
        } else {
            if currentSlide < maxSlides {
                animateSlideTransitionWithCompletion {
                    self.currentSlide += 1
                    self.currentSlideIndex = (self.currentSlideIndex + 1) % self.slides.count
                    self.loadNextSlide()
                }
            } else {
                loadInfoMessage(noMoreSlidesError)
            }
        }
    }
    
    func hasConfigureSheet() -> Bool {
        return false
    }
    
    // MARK: - Slide Transitions
    private func animateSlideTransitionWithCompletion(_ completion: @escaping () -> Void) {
        webView?.isHidden = false
        webView?.alphaValue = 1.0
        
        let currentFrame = webView?.frame ?? .zero
        let startFrame = currentFrame
        let endFrame = currentFrame
        
        let zoomFactor: CGFloat = 1.02
        let fadeAlpha: CGFloat = 0.9
        
        let animationDict: [NSViewAnimation.Key: Any] = [
            .target: webView as Any,
            .startFrame: NSValue(rect: startFrame),
            .endFrame: NSValue(rect: endFrame),
            .effect: NSViewAnimation.EffectName.fadeIn
        ]
        
        let slideAnimation = NSViewAnimation(viewAnimations: [animationDict])
        slideAnimation.duration = Self.slideTransitionDuration * 0.6
        slideAnimation.animationCurve = .easeInOut
        slideAnimation.animationBlockingMode = .nonblocking
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = zoomFactor
        scaleAnimation.duration = Self.slideTransitionDuration * 0.3
        scaleAnimation.autoreverses = true
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 1.0
        fadeAnimation.toValue = fadeAlpha
        fadeAnimation.duration = Self.slideTransitionDuration * 0.2
        fadeAnimation.autoreverses = true
        fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        webView?.wantsLayer = true
        if let layer = webView?.layer {
            layer.add(scaleAnimation, forKey: "slideScale")
            layer.add(fadeAnimation, forKey: "slideFade")
        }
        
        slideAnimation.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.slideTransitionDuration * 0.6) {
            if let layer = self.webView?.layer {
                layer.removeAnimation(forKey: "slideScale")
                layer.removeAnimation(forKey: "slideFade")
            }
            
            self.webView?.alphaValue = 1.0
            self.webView?.isHidden = false
            
            completion()
        }
    }
    
    private func loadNextSlide() {
        guard currentSlideIndex < slides.count else {
            os_log("Invalid slide index %d, total slides: %d", log: Self.logger, type: .error, currentSlideIndex, slides.count)
            return
        }
        
        let nextSlideURL = slides[currentSlideIndex]
        let retryCount = slideLoadRetryCount[nextSlideURL] ?? 0

        // Check if we've exceeded retry attempts. NOTE: consecutiveNavigationFailures (see the
        // WKNavigationDelegate extension) trips at the same threshold and is checked first on
        // every real navigation failure, so in practice this per-slide branch is not expected to
        // be exercised — don't change one threshold without checking the other.
        if retryCount >= maxRetryAttempts {
            os_log("Max retry attempts reached for slide %d, skipping", log: Self.logger, type: .error, currentSlideIndex)
            // Move to next slide
            currentSlideIndex = (currentSlideIndex + 1) % slides.count
            if currentSlideIndex < slides.count {
                loadNextSlide() // Try next slide
            }
            return
        }
        
        let autoplayURL = createAutoplay(link: nextSlideURL, time: Self.stayOnSlideTime?.intValue ?? 0, slide: currentSlideIndex)
        
        os_log("Loading slide %d (attempt %d): %{public}@", log: Self.logger, type: .info, currentSlideIndex, retryCount + 1, nextSlideURL)
        
        if let url = URL(string: autoplayURL) {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30.0)
            webView?.navigationDelegate = self
            
            // ARM64-specific loading optimization
            if Self.isAppleSilicon {
                // Use delayed loading for ARM64 stability
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.webView?.load(request)
                    os_log("ARM64 Loading slide %d (attempt %d): %{public}@", log: Self.logger, type: .info, self.currentSlideIndex, retryCount + 1, nextSlideURL)
                }
            } else {
                // Standard loading for Intel
                webView?.load(request)
                os_log("Loading slide %d (attempt %d): %{public}@", log: Self.logger, type: .info, currentSlideIndex, retryCount + 1, nextSlideURL)
            }
            
            // Increment retry count
            slideLoadRetryCount[nextSlideURL] = retryCount + 1
        } else {
            os_log("Failed to create URL for slide %d: %{public}@", log: Self.logger, type: .error, currentSlideIndex, autoplayURL)
        }
        
        // Start background loading of next slide
        startBackgroundLoadingOfNextSlide()
    }
    
    // MARK: - Debug
    private func showDebugMessage(_ msg: String) {
        let str = "\nSlides: \(msg)"
        textView?.string = (textView?.string ?? "") + str
    }
    
    // MARK: - MDM Configuration
    private func loadMdm() {
        let moduleName = Bundle(for: type(of: self)).bundleIdentifier ?? ""
        let defaults = UserDefaults(suiteName: moduleName)
        
        let link = defaults?.string(forKey: urlKey)
        let resetSlidesWhenStarted = defaults?.object(forKey: resetKey) as? NSNumber
        Self.stayOnSlideTime = defaults?.object(forKey: timeKey) as? NSNumber
        let zoom = defaults?.object(forKey: zoomFullScreenKey) as? NSNumber
        let fill = defaults?.object(forKey: fillEmptySpaceKey) as? NSNumber
        Self.fillEmptySpace = fill?.boolValue ?? false
        let dyn = defaults?.object(forKey: dynamicKey) as? NSNumber
        Self.dynamic = dyn?.boolValue ?? false
        
        Self.emptySpaceFillMode = defaults?.string(forKey: emptySpaceFillModeKey) ?? ""
        Self.emptySpaceFillImage = defaults?.string(forKey: emptySpaceFillImageKey) ?? ""
        
        // Load debug mode setting with safe error handling
        let debugModeEnabled = defaults?.object(forKey: debugModeEnabledKey) as? NSNumber
        Self.debugMode = debugModeEnabled?.boolValue ?? false
        
        os_log("MDM Debug Mode: %{public}@ (default: false)", log: Self.logger, type: .info, Self.debugMode ? "enabled" : "disabled")
        
        var slide = -1
        if resetSlidesWhenStarted?.boolValue == true {
            slide = 0
        } else {
            if let value = UserDefaults.standard.object(forKey: currentSlideKey) as? NSNumber {
                slide = value.intValue
            }
        }
        
        if let link = link, !link.isEmpty {
            initializeSlidesFromLink(link)
            
            instanceCurrentLink = createAutoplay(link: link, time: Self.stayOnSlideTime?.intValue ?? 0, slide: slide)
            animationTimeInterval = Self.stayOnSlideTime?.doubleValue ?? 1.0
            
            print("People.AI loading first slide with URL: \(instanceCurrentLink)")
            print("People.AI slide time: \(Self.stayOnSlideTime ?? 0) seconds")
            
            if let url = URL(string: instanceCurrentLink) {
                let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30.0)
                webView?.navigationDelegate = self
                webView?.load(request)
            }
            
            startBackgroundLoadingOfNextSlide()
            
            if zoom?.boolValue == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.updateWebViewForCurrentDisplay()
                }
            }
        } else {
            loadErrorPage()
        }
        
        if Self.debugMode {
            showDebugMessage("loadConfig parent view rect: \(frame)")
            showDebugMessage("loadConfig web view rect: \(webView?.frame ?? .zero)")
            setupDebugInfoDisplay()
        }
    }
    
    private func saveCurrentSlide() {
        guard let url = webView?.url else { return }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        var queryParams: [String: String] = [:]
        
        for queryItem in components?.queryItems ?? [] {
            if let value = queryItem.value {
                queryParams[queryItem.name] = value
            }
        }
        
        if let strSlide = queryParams["slide"], let slide = Int(strSlide) {
            UserDefaults.standard.set(slide, forKey: currentSlideKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    private func checkViewRefreshTime() {
        // Self-protecting: refuse to schedule a repeating reload timer for an instance that
        // isn't actually the active screensaver, regardless of what caller reaches this.
        guard isScreensaverActive() else {
            os_log("checkViewRefreshTime skipped - screensaver not active", log: Self.logger, type: .info)
            return
        }

        let moduleName = Bundle(for: type(of: self)).bundleIdentifier ?? ""
        let defaults = UserDefaults(suiteName: moduleName)
        let viewRefreshTime = defaults?.object(forKey: viewRefreshTimeKey) as? NSNumber

        let interval = viewRefreshTime?.doubleValue ?? 0
        guard interval >= 1.0 else { return }

        instanceTimer?.invalidate()
        refreshTimerInactiveStreak = 0

        instanceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            guard self.isScreensaverActive() else {
                // Tolerate a single transient miss (e.g. a Spaces/Mission Control blip) before
                // concluding this instance was orphaned (started but never properly stopped).
                self.refreshTimerInactiveStreak += 1
                os_log("Refresh timer fired while inactive (%d/2)", log: Self.logger, type: .info, self.refreshTimerInactiveStreak)
                if self.refreshTimerInactiveStreak >= 2 {
                    os_log("Instance orphaned - tearing down via stopAnimation()", log: Self.logger, type: .info)
                    self.instanceTimer?.invalidate()
                    self.instanceTimer = nil
                    self.stopAnimation()
                }
                return
            }

            self.refreshTimerInactiveStreak = 0
            self.loadMdm()
            print("view refreshed.")
        }
    }
    
    // MARK: - Slide Management
    private func initializeSlidesFromLink(_ link: String) {
        var slidesArray: [String] = []
        slidesArray.append(link)
        
        for i in 1...5 {
            let slideURL = "\(link)?slide=\(i)"
            slidesArray.append(slideURL)
        }
        
        slides = slidesArray
        currentSlideIndex = 0
        isFirstLoop = true
        
        print("People.AI initialized \(slides.count) slides for background loading")
    }
    
    private func createAutoplay(link: String, time: Int, slide: Int) -> String {
        if slide > 0 {
            return "\(link)?rm=\(modeMinimal)&start=true&loop=true&delayms=\(time * 1000)&slide=\(slide)"
        } else {
            return "\(link)?rm=\(modeMinimal)&start=true&loop=true&delayms=\(time * 1000)"
        }
    }
    
    private func loadInfoMessage(_ msg: String) {
        webView?.loadHTMLString(msg, baseURL: nil)
    }
    
    private func loadErrorPage() {
        guard let path = Bundle(for: type(of: self)).path(forResource: "error", ofType: "html") else { return }
        let url = URL(fileURLWithPath: path)
        
        webView?.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    
    // MARK: - Debug Info Display
    private func setupDebugInfoDisplay() {
        guard Self.debugMode else { return }
        
        // Create debug info view in bottom left corner
        let debugFrame = NSRect(x: 10, y: 10, width: 300, height: 200)
        debugInfoView = NSTextView(frame: debugFrame)
        
        guard let debugInfoView = debugInfoView else { return }
        
        debugInfoView.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        debugInfoView.textColor = NSColor.green
        debugInfoView.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        debugInfoView.isEditable = false
        debugInfoView.isSelectable = false
        debugInfoView.drawsBackground = true
        
        // CRITICAL: Add debug view on top of WebView
        addSubview(debugInfoView)
        
        // CRITICAL: Ensure debug view is on top layer
        debugInfoView.wantsLayer = true
        if let debugLayer = debugInfoView.layer {
            debugLayer.zPosition = 1000  // High z-position to appear on top
            debugLayer.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        }
        
        // CRITICAL: Bring debug view to front
        debugInfoView.superview?.addSubview(debugInfoView, positioned: .above, relativeTo: webView)
        
        // Start updating debug info
        updateDebugInfo()
        debugInfoTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateDebugInfo()
        }
        
        os_log("Debug info display enabled on top layer", log: Self.logger, type: .info)
    }
    
    private func updateDebugInfo() {
        guard Self.debugMode, let debugInfoView = debugInfoView else { return }
        
        let screen = getValidCurrentScreen()
        let screenFrame = screen?.frame ?? .zero
        let backingScaleFactor = screen?.backingScaleFactor ?? 1.0
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        let debugInfo = """
        People.AI Screensaver Debug Info
        ================================
        Version: \(version) (\(build))
        Screen: \(screen?.localizedName ?? "Unknown")
        Resolution: \(Int(screenFrame.width))x\(Int(screenFrame.height))
        Scale Factor: \(String(format: "%.1f", backingScaleFactor))
        WebView Frame: \(webView?.frame ?? .zero)
        Parent Frame: \(frame)
        Current Slide: \(currentSlideIndex)
        Scaling Applied: \(scalingApplied)
        Display Detection: \(displayDetectionComplete)
        Memory Usage: \(getMemoryUsage())
        ================================
        """
        
        DispatchQueue.main.async {
            debugInfoView.string = debugInfo
            
            // CRITICAL: Ensure debug view stays on top
            self.ensureDebugViewOnTop()
        }
    }
    
    private func ensureDebugViewOnTop() {
        guard Self.debugMode, let debugInfoView = debugInfoView else { return }
        
        // CRITICAL: Bring debug view to front of all subviews
        debugInfoView.superview?.addSubview(debugInfoView, positioned: .above, relativeTo: nil)
        
        // CRITICAL: Ensure high z-position
        if let debugLayer = debugInfoView.layer {
            debugLayer.zPosition = 1000
        }
        
        // CRITICAL: Position in bottom left corner
        let debugFrame = NSRect(x: 10, y: 10, width: 300, height: 200)
        debugInfoView.frame = debugFrame
    }
    
    private func getMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = info.resident_size / 1024 / 1024
            return "\(usedMB) MB"
        }
        
        return "Unknown"
    }
    
    private func cleanupDebugMode() {
        debugInfoTimer?.invalidate()
        debugInfoTimer = nil
        
        debugInfoView?.removeFromSuperview()
        debugInfoView = nil
        
        os_log("Debug mode cleaned up", log: Self.logger, type: .info)
    }
    
    // MARK: - Modern Async Background Loading
    private func startBackgroundLoadingOfNextSlide() {
        // CRITICAL: Prevent background network activity
        guard isScreensaverActive() else {
            os_log("Preventing background network loading - screensaver not active", log: Self.logger, type: .info)
            return
        }
        
        // Cancel previous preload task
        preloadTask?.cancel()
        
        let nextSlideIndex = (currentSlideIndex + 1) % slides.count
        let nextSlideURL = slides[nextSlideIndex]
        
        // Enhanced cache checking
        if loadingSlides.contains(nextSlideURL) {
            return
        }
        
        loadingSlides.insert(nextSlideURL)
        
        // Create new async task
        preloadTask = Task {
            await preloadSlide(nextSlideURL, index: nextSlideIndex)
        }
    }
    
    private func preloadSlide(_ slideURL: String, index: Int) async {
        // Check if already cached
        let normalizedKey = CacheManager.normalizeKey(from: slideURL)
        if await cacheManager.get(normalizedKey) != nil && !isFirstLoop {
            DispatchQueue.main.async {
                self.loadingSlides.remove(slideURL)
            }
            return
        }
        
        let autoplayURL = createAutoplay(link: slideURL, time: Self.stayOnSlideTime?.intValue ?? 0, slide: index)
        
        guard let url = URL(string: autoplayURL) else {
            DispatchQueue.main.async {
                self.loadingSlides.remove(slideURL)
            }
            return
        }
        
        // Use optimized URLSession configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        config.waitsForConnectivity = false
        config.allowsCellularAccess = false
        
        let session = URLSession(configuration: config)
        
        do {
            let (data, _) = try await session.data(from: url)
            
            // Only cache if data is not too large (prevent memory issues)
            if data.count < 30_000_000 { // 30MB limit
                await cacheManager.set(normalizedKey, value: data)
                os_log("Cached slide %d in background (%d bytes)", log: Self.logger, type: .info, index, data.count)
            } else {
                os_log("Slide %d too large to cache (%d bytes), skipping", log: Self.logger, type: .info, index, data.count)
            }
        } catch {
            os_log("Failed to preload slide %d: %{public}@", log: Self.logger, type: .error, index, error.localizedDescription)
        }
        
        DispatchQueue.main.async {
            self.loadingSlides.remove(slideURL)
        }
    }
    
    
    // MARK: - Optimized Image Processing
    private func convertToBlurImage(_ image: NSImage) -> NSImage? {
        // Use shared context for better performance - conservative settings for stability
        let context = Self.sharedContext ?? CIContext(options: [
            .workingColorSpace: NSNull(),
            .useSoftwareRenderer: false,
            .priorityRequestLow: true,  // Conservative priority for stability
            .cacheIntermediates: false  // Disable caching for memory efficiency
        ])
        Self.sharedContext = context
        
        guard let tiffData = image.tiffRepresentation,
              let inputImage = CIImage(data: tiffData) else { 
            os_log("Failed to create CIImage from NSImage", log: Self.logger, type: .error)
            return nil 
        }
        
        // Dynamic scale factor based on image size and display resolution
        let imageSize = image.size
        let maxDimension = max(imageSize.width, imageSize.height)
        
        // Get display resolution info for optimal scaling
        let displayInfo = getDisplayResolutionInfo()
        let baseScaleFactor: CGFloat = maxDimension > 2000 ? 0.3 : (maxDimension > 1000 ? 0.4 : 0.6)
        
        // Adjust scale factor for Retina displays - conservative approach
        let scaleFactor: CGFloat
        if displayInfo.isRetina {
            scaleFactor = baseScaleFactor * 1.2  // Higher quality for Retina displays
        } else {
            scaleFactor = baseScaleFactor
        }
        
        let scaledImage = inputImage.transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        
        // Dynamic blur radius based on image size - conservative approach
        let blurRadius: CGFloat = maxDimension > 2000 ? 8 : (maxDimension > 1000 ? 10 : 12)
        
        let gaussianBlurFilter = CIFilter(name: "CIGaussianBlur")
        gaussianBlurFilter?.setDefaults()
        gaussianBlurFilter?.setValue(scaledImage, forKey: kCIInputImageKey)
        gaussianBlurFilter?.setValue(blurRadius, forKey: kCIInputRadiusKey)
        
        guard let outputImage = gaussianBlurFilter?.outputImage else { 
            os_log("Failed to create blurred output image", log: Self.logger, type: .error)
            return nil 
        }
        
        // Use optimized rendering
        let extent = outputImage.extent
        guard let cgimg = context.createCGImage(outputImage, from: extent) else { 
            os_log("Failed to create CGImage from blurred image", log: Self.logger, type: .error)
            return nil 
        }
        
        let convertedImage = NSImage(cgImage: cgimg, size: NSSize(width: cgimg.width, height: cgimg.height))
        
        let architecture = Self.isAppleSilicon ? "Apple Silicon (ARM64)" : "Intel (x86_64)"
        os_log("Image processing [%@]: input %.1fx%.1f -> output %.1fx%.1f, scale %.2f, radius %.1f", log: Self.logger, type: .info, architecture, image.size.width, image.size.height, convertedImage.size.width, convertedImage.size.height, scaleFactor, blurRadius)
        return convertedImage
    }
    
    private func performImageUpdate() {
        if #available(macOS 10.13, *) {
            let wkSnapshotConfig = WKSnapshotConfiguration()
            wkSnapshotConfig.snapshotWidth = NSNumber(value: Int(frame.size.width))
            
            webView?.takeSnapshot(with: wkSnapshotConfig) { [weak self] snapshotImage, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("People.AI snapshot error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshotImage = snapshotImage else {
                    print("People.AI snapshot failed: No image returned")
                    return
                }
                
                if self.imageView == nil {
                    self.setupOptimizedImageView()
                }
                
                // Calculate optimal image size based on display and aspect ratio
                let optimizedSize = self.calculateOptimalImageSize(from: snapshotImage.size)
                let resizedImage = snapshotImage.resize(to: optimizedSize)
                os_log("Optimized image size: %.1f x %.1f (from %.1f x %.1f)", log: Self.logger, type: .info, optimizedSize.width, optimizedSize.height, snapshotImage.size.width, snapshotImage.size.height)
                
                self.imageView?.image = self.convertToBlurImage(resizedImage)
                self.imageView?.imageScaling = .scaleAxesIndependently
            }
        }
    }
    
    // MARK: - Optimized Image Sizing
    private func setupOptimizedImageView() {
        guard let screen = getValidCurrentScreen() else { return }
        
        let screenFrame = screen.frame
        let aspectRatio = screenFrame.size.width / screenFrame.size.height
        
        // Calculate optimal imageView size based on display aspect ratio
        let imageViewSize = calculateOptimalImageViewSize(for: screenFrame, aspectRatio: aspectRatio)
        
        imageView = NSImageView(frame: imageViewSize)
        if let imageView = imageView {
            addSubview(imageView, positioned: .below, relativeTo: webView)
            imageView.imageScaling = .scaleAxesIndependently
        }
        
        os_log("Setup optimized imageView: %{public}@ for aspect ratio %.2f", log: Self.logger, type: .info, imageViewSize.debugDescription, aspectRatio)
    }
    
    private func calculateOptimalImageViewSize(for screenFrame: NSRect, aspectRatio: CGFloat) -> NSRect {
        let screenWidth = screenFrame.size.width
        let screenHeight = screenFrame.size.height
        
        // Calculate padding based on aspect ratio
        let paddingFactor: CGFloat
        if aspectRatio > 2.0 {
            paddingFactor = 0.5  // Ultra-wide: minimal padding
        } else if aspectRatio > 1.5 {
            paddingFactor = 0.75 // Wide: moderate padding
        } else if aspectRatio < 0.7 {
            paddingFactor = 0.5  // Vertical: minimal padding
        } else {
            paddingFactor = 1.0  // Standard: normal padding
        }
        
        let paddingX = screenWidth * paddingFactor
        let paddingY = screenHeight * paddingFactor
        
        return NSRect(
            x: -paddingX,
            y: -paddingY,
            width: screenWidth + (2 * paddingX),
            height: screenHeight + (2 * paddingY)
        )
    }
    
    private func calculateOptimalImageSize(from originalSize: CGSize) -> CGSize {
        guard let screen = getValidCurrentScreen() else {
            // Fallback: reduce by 2x
            return CGSize(width: originalSize.width / 2, height: originalSize.height / 2)
        }
        
        let screenFrame = screen.frame
        let aspectRatio = screenFrame.size.width / screenFrame.size.height
        let imageAspectRatio = originalSize.width / originalSize.height
        let backingScaleFactor = screen.backingScaleFactor
        
        // Calculate optimal scale based on display and image aspect ratios
        var scaleFactor: CGFloat
        if aspectRatio > 2.0 {
            scaleFactor = 0.3  // Ultra-wide: aggressive scaling
        } else if aspectRatio > 1.5 {
            scaleFactor = 0.4  // Wide: moderate scaling
        } else if aspectRatio < 0.7 {
            scaleFactor = 0.3  // Vertical: aggressive scaling
        } else {
            scaleFactor = 0.5  // Standard: normal scaling
        }
        
        // Adjust for Retina displays - conservative approach for stability
        if backingScaleFactor > 2.0 {
            scaleFactor *= 1.5  // Ultra-high DPI: increase quality
        } else if backingScaleFactor > 1.0 {
            scaleFactor *= 1.2  // Retina display: increase quality
        }
        
        // Adjust for aspect ratio mismatch
        let adjustedScale = imageAspectRatio > aspectRatio * 1.5 ? scaleFactor * 0.8 : scaleFactor
        
        return CGSize(
            width: originalSize.width * adjustedScale,
            height: originalSize.height * adjustedScale
        )
    }
    
    private func setImageBack() {
        if imageView == nil {
            setupOptimizedImageView()
        }
        
        if let imageURL = URL(string: Self.emptySpaceFillImage) {
            imageView?.image = NSImage(contentsOf: imageURL)
        }
        os_log("Loading back image: %{public}@", log: Self.logger, type: .info, Self.emptySpaceFillImage)
        imageView?.imageScaling = .scaleAxesIndependently
    }
    
    // MARK: - Critical Background Cleanup
    private func cancelAllNetworkRequests() {
        // Cancel preload task
        preloadTask?.cancel()
        preloadTask = nil
        
        // Cancel all URLSession tasks
        URLSession.shared.invalidateAndCancel()
        
        // Stop WebView loading
        webView?.stopLoading()
        
        // Clear loading slides
        loadingSlides.removeAll()
        
        os_log("All network requests cancelled", log: Self.logger, type: .info)
    }
    
    private func performCompleteCleanup() {
        // Clear all caches using Actor
        Task { [weak self] in
            await self?.cacheManager.clear()
        }
        loadingSlides.removeAll()
        displayContentZoomCache.removeAll()
        displayResolutionCache.removeAll()
        
        // Clear WebView completely
        webView?.loadHTMLString("", baseURL: nil)
        webView?.removeFromSuperview()
        
        // Force garbage collection
        DispatchQueue.global(qos: .background).async {
            autoreleasepool {
                // Force memory cleanup
            }
        }
        
        os_log("Complete cleanup performed", log: Self.logger, type: .info)
    }
    
    private func resetAllStateVariables() {
        // Reset all state variables to prevent background activity
        scalingApplied = false
        displayDetectionComplete = false
        contentZoomApplied = false
        zoomLockApplied = false
        graphicsContextConfigured = false
        
        // Reset counters
        scalingValidationCount = 0
        scalingResetCount = 0
        slideLoadRetryCount.removeAll()
        consecutiveNavigationFailures = 0
        
        // Reset timestamps
        lastScalingTime = Date()
        lastMemoryCleanup = Date()
        
        // Reset display state
        lastDisplayIdentifier = ""
        lastContentZoomDisplay = ""
        currentBackingScaleFactor = 1.0
        
        os_log("All state variables reset", log: Self.logger, type: .info)
    }
    
    // MARK: - Force Memory Cleanup
    private func forceMemoryCleanup() {
        // Clear all caches immediately using Actor
        Task { [weak self] in
            await self?.cacheManager.clear()
        }
        loadingSlides.removeAll()
        displayContentZoomCache.removeAll()
        displayResolutionCache.removeAll()
        slideLoadRetryCount.removeAll()
        
        // Clear Core Image context
        Self.sharedContext = nil
        
        // Force garbage collection
        autoreleasepool {
            // Clear any remaining references
            imageView?.image = nil
            textView?.string = ""
        }
        
        // Clear display-specific caches
        currentBackingScaleFactor = 1.0
        lastContentZoomDisplay = ""
        
        // Clean up debug mode
        cleanupDebugMode()
        
        os_log("Force memory cleanup completed", log: Self.logger, type: .info)
    }
    
    // MARK: - Optimized Cleanup
    deinit {
        os_log("Screensaver deinit started", log: Self.logger, type: .info)
        
        // CRITICAL: Stop all WebView activity first
        stopWebViewActivity()
        
        // CRITICAL: Invalidate ALL timers (including static ones)
        instanceTimer?.invalidate()
        instanceAnimationTimer?.invalidate()
        Self.animationTimer?.invalidate()
        periodicCleanupTimer?.invalidate()
        scalingResetTimer?.invalidate()
        errorRecoveryTimer?.invalidate()
        instanceTimer = nil
        instanceAnimationTimer = nil
        periodicCleanupTimer = nil
        scalingResetTimer = nil
        errorRecoveryTimer = nil
        
        // Clean up memory pressure monitoring
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        
        // Clean up periodic cleanup timer
        periodicCleanupTimer?.invalidate()
        periodicCleanupTimer = nil
        
        // CRITICAL: Cancel all network requests
        URLSession.shared.invalidateAndCancel()
        
        // CRITICAL: Clear all caches and memory using Actor
        Task { [weak self] in
            await self?.cacheManager.clear()
        }
        loadingSlides.removeAll()
        displayContentZoomCache.removeAll()
        displayResolutionCache.removeAll()
        slideLoadRetryCount.removeAll()
        
        // Clean up WebView
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        
        // Enhanced cleanup for different macOS versions with safe JavaScript execution
        if #available(macOS 15.0, *) {
            webView?.evaluateJavaScript("window.stop();") { result, error in
                if let error = error {
                    os_log("JavaScript cleanup failed: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
                }
            }
            webView?.loadHTMLString("", baseURL: nil)
            webView?.removeFromSuperview()
        } else if #available(macOS 10.15, *) {
            webView?.loadHTMLString("", baseURL: nil)
            webView?.evaluateJavaScript("window.stop();") { result, error in
                if let error = error {
                    os_log("JavaScript cleanup failed: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
                }
            }
        }
        
        // Clear WebView reference
        webView = nil
        imageView = nil
        textView = nil
        
        // Remove all observers
        NotificationCenter.default.removeObserver(self)
        
        // Clear Combine subscriptions
        cancellables.removeAll()
        
        // CRITICAL: Force final memory cleanup
        forceMemoryCleanup()
        
        os_log("Screensaver deinit completed", log: Self.logger, type: .info)
    }
}

// MARK: - WKScriptMessageHandler
extension PeopleScreensaverView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "errorHandler" {
            if let errorMessage = message.body as? String {
                os_log("JavaScript error: %{public}@", log: Self.logger, type: .error, errorMessage)
            }
        }
    }
}

// MARK: - WKNavigationDelegate
extension PeopleScreensaverView: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    private func handleNavigationFailure(_ error: Error) {
        consecutiveNavigationFailures += 1
        os_log("Navigation failed for slide %d (consecutive failure %d/%d): %{public}@",
               log: Self.logger, type: .error, currentSlideIndex,
               consecutiveNavigationFailures, maxConsecutiveNavigationFailures,
               error.localizedDescription)

        guard consecutiveNavigationFailures < maxConsecutiveNavigationFailures else {
            os_log("Consecutive navigation failures reached threshold, showing error page",
                   log: Self.logger, type: .error)
            loadErrorPage()
            scheduleErrorRecovery()
            return
        }

        // Exponential backoff (1s, 2s, 4s, capped) so a real outage doesn't hammer the network/CPU.
        let backoff = min(pow(2.0, Double(consecutiveNavigationFailures - 1)), 16.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + backoff) { [weak self] in
            self?.loadNextSlide()
        }
    }

    private func scheduleErrorRecovery() {
        guard errorRecoveryTimer == nil else { return } // avoid stacking timers on repeat failures
        os_log("Scheduling automatic recovery attempt in %.0fs", log: Self.logger, type: .info, errorRecoveryInterval)
        errorRecoveryTimer = Timer.scheduledTimer(withTimeInterval: errorRecoveryInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.errorRecoveryTimer = nil
            os_log("Attempting recovery from error page", log: Self.logger, type: .info)
            self.loadMdm()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Reset failure tracking on a real slide load, but not on the error.html file load itself
        // (otherwise successfully showing the error page would immediately cancel its own recovery timer).
        if webView.url?.isFileURL != true {
            if consecutiveNavigationFailures > 0 {
                os_log("Slide navigation recovered after %d consecutive failure(s)",
                       log: Self.logger, type: .info, consecutiveNavigationFailures)
            }
            consecutiveNavigationFailures = 0
            errorRecoveryTimer?.invalidate()
            errorRecoveryTimer = nil
        }

        // Safe JavaScript execution with error handling
        let script = "document.body.style = document.body.style.cssText + \";background: transparent !important;\";"
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                os_log("JavaScript execution failed: %{public}@", log: Self.logger, type: .error, error.localizedDescription)
            } else {
                os_log("JavaScript executed successfully", log: Self.logger, type: .info)
            }
        }
        
        // Apply display-specific content zoom after page load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.applyDisplaySpecificContentZoom()
        }
        
        print("People.AI screensaver didFinishNavigation for slide \(currentSlideIndex)")
        
        // Check for WebView teardown cycle
        checkForTeardownCycle()
        
        // Reset retry count on successful load
        if currentSlideIndex < slides.count {
            let currentSlideURL = slides[currentSlideIndex]
            slideLoadRetryCount.removeValue(forKey: currentSlideURL)
            os_log("Slide %d loaded successfully, retry count reset", log: Self.logger, type: .info, currentSlideIndex)
        }
        
        if isFirstLoop && currentSlideIndex < slides.count {
            let currentSlideURL = slides[currentSlideIndex]
            cacheCurrentSlideContent(currentSlideURL)
        }
        
        webView.isHidden = false
        webView.alphaValue = 1.0
        
        if Self.emptySpaceFillMode == "dynamic" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.performImageUpdate()
            }
            
            instanceAnimationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval((Self.stayOnSlideTime?.intValue ?? 0) + 1), repeats: true) { _ in
                self.performImageUpdate()
            }
        } else if Self.emptySpaceFillMode == "static" {
            if !Self.emptySpaceFillImage.isEmpty {
                setImageBack()
            }
        } else if Self.emptySpaceFillMode == "none" {
            // Do nothing
        } else {
            performImageUpdate()
        }
    }
    
    private func cacheCurrentSlideContent(_ slideURL: String) {
        webView?.evaluateJavaScript("document.documentElement.outerHTML") { result, error in
            if error == nil, let htmlString = result as? String {
                if let htmlData = htmlString.data(using: .utf8) {
                    let normalizedKey = CacheManager.normalizeKey(from: slideURL)
                    Task { [weak self] in
                        await self?.cacheManager.set(normalizedKey, value: htmlData)
                    }
                    print("People.AI cached current slide \(self.currentSlideIndex) content")
                }
            }
        }
    }
}

// MARK: - NSImage Extension
extension NSImage {
    func resize(to size: CGSize) -> NSImage {
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: size))
        resizedImage.unlockFocus()
        return resizedImage
    }
}
