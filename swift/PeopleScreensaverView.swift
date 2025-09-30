//
//  PeopleScreensaverView.swift
//  People.ai Screensaver
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2024 People.ai, Inc. All rights reserved.
//

import ScreenSaver
import WebKit
import CoreImage
import AppKit
import Foundation

// MARK: - Configuration Keys
private struct ConfigKeys {
    static let slidesUrl = "slidesUrl"
    static let stayOnSlideTime = "stayOnSlideTime"
    static let resetSlidesWhenStarted = "resetSlidesWhenStarted"
    static let currentSlideKey = "currentSlideKey"
    static let maxSlides = "maxSlides"
    static let zoomForFullScreen = "zoomForFullScreen"
    static let viewRefreshTime = "viewRefreshTime"
    static let fillEmptySpace = "fillEmptySpace"
    static let dynamic = "dynamic"
    static let emptySpaceFillImage = "emptySpaceFillImage"
    static let emptySpaceFillMode = "emptySpaceFillMode"
}

// MARK: - Screensaver Error Types
enum ScreensaverError: Error, LocalizedError {
    case networkFailure(String)
    case configurationError(String)
    case displayError(String)
    case slideLoadingError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkFailure(let message):
            return "Network error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .displayError(let message):
            return "Display error: \(message)"
        case .slideLoadingError(let message):
            return "Slide loading error: \(message)"
        }
    }
}

// MARK: - Main Screensaver View
class PeopleScreensaverView: ScreenSaverView {
    
    // MARK: - Properties
    private var webView: ScreensaverWebView!
    private var imageView: NSImageView?
    private var textView: NSTextView?
    
    // Configuration
    private var baseLink: String = ""
    private var currentSlide: Int = 0
    private var maxSlides: Int = 0
    private var slideTime: Int = 0
    private var slides: [String] = []
    
    // Caching and loading
    private var slideCache: [String: Data] = [:]
    private var loadingSlides: Set<String> = []
    private var currentSlideIndex: Int = 0
    private var isFirstLoop: Bool = true
    private var currentLink: String = ""
    
    // Timers
    private var instanceTimer: Timer?
    private var instanceAnimationTimer: Timer?
    
    // Display scaling
    private var instanceResizeWidth: CGFloat = 0.05
    private var instanceResizeHeight: CGFloat = 0.05
    private var scalingApplied: Bool = false
    private var displayDetectionComplete: Bool = false
    
    // Animation
    private let slideTransitionDuration: TimeInterval = 0.8
    private var currentSlideAnimation: NSViewAnimation?
    
    // Core Image context
    private static var sharedContext: CIContext?
    
    // Debug mode
    private let debugMode = false
    private let mdmMode = true
    
    // MARK: - Initialization
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setupScreensaver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScreensaver()
    }
    
    private func setupScreensaver() {
        setupWebView()
        setupNotifications()
        initializeProperties()
        
        if mdmMode {
            loadMdmConfiguration()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkViewRefreshTime()
                self.animationTimeInterval = 1.0
            }
        }
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.setValue(NSNumber(value: false), forKey: "drawsBackground")
        config.processPool = WKProcessPool()
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.allowsAirPlayForMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all
        
        if #available(macOS 15.0, *) {
            let userContentController = WKUserContentController()
            config.userContentController = userContentController
            config.suppressesIncrementalRendering = true
        } else if #available(macOS 10.15, *) {
            config.suppressesIncrementalRendering = true
        }
        
        webView = ScreensaverWebView(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height), configuration: config)
        webView.wantsLayer = true
        addSubview(webView)
        
        autoresizingMask = [.width, .height]
        autoresizesSubviews = true
        webView.autoresizingMask = [.width, .height]
        
        if debugMode {
            setupDebugView()
        }
    }
    
    private func setupDebugView() {
        textView = NSTextView(frame: CGRect(x: 0, y: 0, width: 500, height: 300))
        addSubview(textView!)
        textView?.textColor = .red
        textView?.backgroundColor = .white
        showDebugMessage("Initial parent view rect: \(frame)")
        showDebugMessage("Initial web view rect: \(webView.frame)")
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    private func initializeProperties() {
        slideCache = [:]
        loadingSlides = []
        currentSlideIndex = 0
        isFirstLoop = true
        currentLink = ""
        instanceResizeWidth = 0.05
        instanceResizeHeight = 0.05
        scalingApplied = false
        displayDetectionComplete = false
    }
    
    // MARK: - Lifecycle
    deinit {
        cleanup()
    }
    
    private func cleanup() {
        instanceTimer?.invalidate()
        instanceTimer = nil
        instanceAnimationTimer?.invalidate()
        instanceAnimationTimer = nil
        
        slideCache.removeAll()
        loadingSlides.removeAll()
        currentLink = ""
        
        webView.navigationDelegate = nil
        webView.stopLoading()
        
        if #available(macOS 15.0, *) {
            handleMacOS15StopAnimation()
        } else if #available(macOS 10.15, *) {
            handleOlderMacOSStopAnimation()
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Frame Updates
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateWebViewForCurrentDisplay()
        
        if debugMode {
            showDebugMessage("setFrame parent view rect: \(frame)")
            showDebugMessage("setFrame web view rect: \(webView.frame)")
            showDebugMessage("Current display: \(getCurrentDisplayInfo())")
        }
    }
    
    // MARK: - Animation Control
    override func startAnimation() {
        super.startAnimation()
    }
    
    override func stopAnimation() {
        super.stopAnimation()
        
        instanceTimer?.invalidate()
        instanceTimer = nil
        instanceAnimationTimer?.invalidate()
        instanceAnimationTimer = nil
        
        currentSlideAnimation?.stop()
        currentSlideAnimation = nil
        
        NotificationCenter.default.removeObserver(self)
        webView.navigationDelegate = nil
        webView.stopLoading()
        
        if #available(macOS 15.0, *) {
            handleMacOS15StopAnimation()
        } else if #available(macOS 10.15, *) {
            handleOlderMacOSStopAnimation()
        }
    }
    
    private func handleMacOS15StopAnimation() {
        if #available(macOS 15.0, *) {
            webView.evaluateJavaScript("window.stop();", completionHandler: nil)
            webView.loadHTMLString("", baseURL: nil)
            webView.evaluateJavaScript("if (window.gc) { window.gc(); }", completionHandler: nil)
        }
    }
    
    private func handleOlderMacOSStopAnimation() {
        if #available(macOS 10.15, *) {
            webView.loadHTMLString("", baseURL: nil)
            webView.evaluateJavaScript("window.stop();", completionHandler: nil)
        }
    }
    
    // MARK: - Animation Frame
    override func animateOneFrame() {
        if mdmMode {
            saveCurrentSlide()
        } else {
            if currentSlide < maxSlides {
                animateSlideTransition {
                    self.currentSlide += 1
                }
            } else {
                loadInfoMessage("<html><body><b>No more slides</b></body></html>")
            }
        }
    }
    
    func hasConfigureSheet() -> Bool {
        return false
    }
    
    // MARK: - Debug Support
    private func showDebugMessage(_ message: String) {
        guard debugMode else { return }
        let debugText = "\nSlides: \(message)"
        textView?.string = (textView?.string ?? "") + debugText
    }
    
    // MARK: - Configuration Management
    private func loadMdmConfiguration() {
        let configManager = ConfigurationManager()
        let config = configManager.loadConfiguration()
        
        guard let link = config.slidesUrl, !link.isEmpty else {
            loadErrorPage()
            return
        }
        
        baseLink = link
        slideTime = config.stayOnSlideTime ?? 5
        maxSlides = config.maxSlides ?? 5
        
        let resetSlides = config.resetSlidesWhenStarted ?? true
        let currentSlide = resetSlides ? 0 : configManager.getCurrentSlide()
        
        initializeSlidesFromLink(link)
        
        currentLink = createAutoplayURL(from: link, time: slideTime, slide: currentSlide)
        animationTimeInterval = Double(slideTime)
        
        print("People.AI loading first slide with URL: \(currentLink)")
        print("People.AI slide time: \(slideTime) seconds")
        
        loadSlideFromURL(currentLink)
        
        // Start background loading
        startBackgroundLoadingOfNextSlide()
        
        // Apply display scaling if enabled
        if config.zoomForFullScreen == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.updateWebViewForCurrentDisplay()
            }
        }
        
        if debugMode {
            showDebugMessage("loadConfig parent view rect: \(frame)")
            showDebugMessage("loadConfig web view rect: \(webView.frame)")
        }
    }
    
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
    
    private func createAutoplayURL(from link: String, time: Int, slide: Int) -> String {
        if slide > 0 {
            return "\(link)?rm=minimal&start=true&loop=true&delayms=\(time * 1000)&slide=\(slide)"
        } else {
            return "\(link)?rm=minimal&start=true&loop=true&delayms=\(time * 1000)"
        }
    }
    
    private func loadSlideFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("People.AI invalid URL: \(urlString)")
            loadErrorPage()
            return
        }
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30.0)
        webView.navigationDelegate = self
        webView.load(request)
    }
    
    private func startBackgroundLoadingOfNextSlide() {
        let nextSlideIndex = (currentSlideIndex + 1) % slides.count
        let nextSlideURL = slides[nextSlideIndex]
        
        guard !loadingSlides.contains(nextSlideURL) else { return }
        guard slideCache[nextSlideURL] == nil || isFirstLoop else { return }
        
        loadingSlides.insert(nextSlideURL)
        
        Task {
            do {
                let data = try await loadSlideData(from: nextSlideURL)
                await MainActor.run {
                    self.loadingSlides.remove(nextSlideURL)
                    self.slideCache[nextSlideURL] = data
                    print("People.AI cached slide \(nextSlideIndex) in background")
                }
            } catch {
                await MainActor.run {
                    self.loadingSlides.remove(nextSlideURL)
                    print("People.AI failed to preload slide \(nextSlideIndex): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadSlideData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw ScreensaverError.networkFailure("Invalid URL: \(urlString)")
        }
        
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30.0)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ScreensaverError.networkFailure("HTTP error: \(response)")
        }
        
        return data
    }
    
    // MARK: - Display Management
    private func updateWebViewForCurrentDisplay() {
        let configManager = ConfigurationManager()
        let config = configManager.loadConfiguration()
        let zoomEnabled = config.zoomForFullScreen ?? false
        
        let displayScaler = DisplayScaler()
        displayScaler.updateWebViewForCurrentDisplay(webView, bounds: bounds, zoomEnabled: zoomEnabled)
    }
    
    @objc private func displayConfigurationChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            let displayScaler = DisplayScaler()
            displayScaler.resetScaling()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateWebViewForCurrentDisplay()
                
                if self.debugMode {
                    self.showDebugMessage("Display configuration changed - updating layout")
                    self.showDebugMessage(self.getCurrentDisplayInfo())
                }
            }
        }
    }
    
    private func getCurrentDisplayInfo() -> String {
        let displayScaler = DisplayScaler()
        return displayScaler.getCurrentDisplayInfo(for: self)
    }
    
    // MARK: - Slide Management
    private func saveCurrentSlide() {
        guard let url = webView.url else { return }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        var queryParams: [String: String] = [:]
        
        for queryItem in components?.queryItems ?? [] {
            if let value = queryItem.value {
                queryParams[queryItem.name] = value
            }
        }
        
        if let slideString = queryParams["slide"],
           let slide = Int(slideString) {
            let configManager = ConfigurationManager()
            configManager.setCurrentSlide(slide)
        }
    }
    
    private func checkViewRefreshTime() {
        let configManager = ConfigurationManager()
        let config = configManager.loadConfiguration()
        
        guard let refreshTime = config.viewRefreshTime, refreshTime >= 1.0 else { return }
        
        instanceTimer?.invalidate()
        
        instanceTimer = Timer.scheduledTimer(withTimeInterval: refreshTime, repeats: true) { [weak self] _ in
            guard let self = self, !self.isHidden else { return }
            self.loadMdmConfiguration()
            print("view refreshed.")
        }
    }
    
    // MARK: - Error Handling
    private func loadErrorPage() {
        let errorHTML = """
        <html>
        <body style="background: #000; color: #fff; font-family: Arial, sans-serif; text-align: center; padding-top: 50px;">
            <h2>Error while loading config file</h2>
            <p>Please check your configuration settings.</p>
        </body>
        </html>
        """
        webView.loadHTMLString(errorHTML, baseURL: nil)
    }
    
    private func loadInfoMessage(_ message: String) {
        webView.loadHTMLString(message, baseURL: nil)
    }
    
    // MARK: - Animation
    private func animateSlideTransition(completion: @escaping () -> Void) {
        let animationManager = AnimationManager()
        animationManager.animateSlideTransition(for: webView) {
            completion()
        }
    }
}

// MARK: - WKNavigationDelegate
extension PeopleScreensaverView: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("People.AI screensaver navigation failed: \(error.localizedDescription)")
        loadErrorPage()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("People.AI screensaver provisional navigation failed: \(error.localizedDescription)")
        loadErrorPage()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Make background transparent
        let script = "document.body.style = document.body.style.cssText + \";background: transparent !important;\";"
        webView.evaluateJavaScript(script, completionHandler: nil)
        print("People.AI screensaver didFinishNavigation for slide \(currentSlideIndex)")
        
        // Cache current slide content if first loop
        if isFirstLoop && currentSlideIndex < slides.count {
            let currentSlideURL = slides[currentSlideIndex]
            cacheCurrentSlideContent(currentSlideURL)
        }
        
        webView.isHidden = false
        webView.alphaValue = 1.0
        
        // Apply background effects
        let configManager = ConfigurationManager()
        let config = configManager.loadConfiguration()
        
        let backgroundManager = BackgroundEffectManager()
        let mode = BackgroundEffectManager.BackgroundMode(rawValue: config.emptySpaceFillMode ?? "none") ?? .none
        
        backgroundManager.applyBackgroundEffect(
            mode: mode,
            webView: webView,
            parentView: self,
            fillImage: config.emptySpaceFillImage,
            slideTime: slideTime
        )
    }
    
    private func cacheCurrentSlideContent(_ slideURL: String) {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            guard let self = self, let htmlString = result as? String, error == nil else { return }
            
            let htmlData = htmlString.data(using: .utf8)
            self.slideCache[slideURL] = htmlData
            print("People.AI cached current slide \(self.currentSlideIndex) content")
        }
    }
}
