//
//  PeopleScreensaverView.swift
//  People.ai
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2022 People.ai, Inc. All rights reserved.
//

import ScreenSaver
import WebKit
import AppKit
import CoreImage
import QuartzCore
import Combine

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

private let configFile = "ai.people.screensaver"
private let modeMinimal = "minimal"
private let configError = "<html><body><b>Error while loading config file</b></body></html>"
private let noMoreSlidesError = "<html><body><b>No more slides</b></body></html>"

// MARK: - Main Screensaver View
class PeopleScreensaverView: ScreenSaverView {
    
    // MARK: - Properties
    private var webView: WKWebViewCustom?
    private var textView: NSTextView?
    private var imageView: NSImageView?
    
    private var baseLink: String = ""
    private var currentSlide: Int = 0
    private var maxSlides: Int = 0
    private var slideTime: Int = 0
    private var slides: [String] = []
    
    private var slideCache: [String: Data] = [:]
    private var loadingSlides: Set<String> = []
    private var currentSlideIndex: Int = 0
    private var isFirstLoop: Bool = true
    private var instanceTimer: Timer?
    private var instanceAnimationTimer: Timer?
    private var instanceCurrentLink: String = ""
    
    private var instanceResizeWidth: CGFloat = 0.05
    private var instanceResizeHeight: CGFloat = 0.05
    private var scalingApplied: Bool = false
    private var displayDetectionComplete: Bool = false
    
    // MARK: - Static Configuration
    private static let mdmMode = true
    private static let debugMode = false
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
        
        if Self.mdmMode {
            loadMdm()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkViewRefreshTime()
                self.animationTimeInterval = 1.0
            }
        }
    }
    
    // MARK: - WebView Setup
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
        
        webView = WKWebViewCustom(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height), configuration: config)
        
        guard let webView = webView else { return }
        
        webView.wantsLayer = true
        addSubview(webView)
        autoresizingMask = [.width, .height]
        autoresizesSubviews = true
        webView.autoresizingMask = [.width, .height]
        
        if Self.debugMode {
            setupDebugView()
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
        DispatchQueue.main.async {
            self.scalingApplied = false
            self.displayDetectionComplete = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateWebViewForCurrentDisplay()
                
                if Self.debugMode {
                    self.showDebugMessage("Display configuration changed - updating layout")
                    self.showDebugMessage(self.getCurrentDisplayInfo())
                }
            }
        }
    }
    
    // MARK: - Initial State
    private func setupInitialState() {
        slideCache = [:]
        loadingSlides = []
        currentSlideIndex = 0
        isFirstLoop = true
        instanceCurrentLink = ""
        
        instanceResizeWidth = 0.05
        instanceResizeHeight = 0.05
        scalingApplied = false
        displayDetectionComplete = false
    }
    
    // MARK: - Frame Updates
    func setFrame(_ frameRect: NSRect) {
        frame = frameRect
        updateWebViewForCurrentDisplay()
        
        if Self.debugMode {
            showDebugMessage("setFrame parent view rect: \(frame)")
            showDebugMessage("setFrame web view rect: \(webView?.frame ?? .zero)")
            showDebugMessage("Current display: \(getCurrentDisplayInfo())")
        }
    }
    
    // MARK: - Display Management
    private func updateWebViewForCurrentDisplay() {
        if scalingApplied {
            print("People.AI scaling already applied, skipping to prevent cumulative effects")
            return
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
            calculateInstanceScalingForAspectRatio(aspectRatio)
            applyValidatedScaling()
            
            if Self.debugMode {
                showDebugMessage("Instance scaling applied: width=\(instanceResizeWidth), height=\(instanceResizeHeight), aspect=\(aspectRatio)")
            }
        } else {
            applyDefaultScaling()
        }
        
        scalingApplied = true
        displayDetectionComplete = true
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
        if let window = window, let screen = window.screen {
            let screenFrame = screen.frame
            if screenFrame.size.width > 0 && screenFrame.size.height > 0 {
                return screen
            }
        }
        
        let mainScreen = NSScreen.main
        let screenFrame = mainScreen?.frame ?? .zero
        if screenFrame.size.width > 0 && screenFrame.size.height > 0 {
            return mainScreen
        }
        
        return nil
    }
    
    // MARK: - Scaling Calculations
    private func calculateInstanceScalingForAspectRatio(_ aspectRatio: CGFloat) {
        instanceResizeWidth = 0.05
        instanceResizeHeight = 0.05
        
        if aspectRatio > 2.0 {
            instanceResizeWidth = 0.03
            instanceResizeHeight = 0.03
        } else if aspectRatio > 1.5 {
            instanceResizeWidth = 0.04
            instanceResizeHeight = 0.04
        } else if aspectRatio < 0.7 {
            instanceResizeWidth = 0.03
            instanceResizeHeight = 0.03
        } else {
            instanceResizeWidth = 0.05
            instanceResizeHeight = 0.05
        }
        
        instanceResizeWidth = min(instanceResizeWidth, 0.01)
        instanceResizeHeight = min(instanceResizeHeight, 0.01)
        
        print("People.AI calculated instance scaling: width=\(instanceResizeWidth), height=\(instanceResizeHeight) for aspect=\(aspectRatio)")
    }
    
    private func applyValidatedScaling() {
        if instanceResizeWidth <= 0 || instanceResizeHeight <= 0 ||
           instanceResizeWidth > 0.1 || instanceResizeHeight > 0.1 {
            print("People.AI invalid scaling values, using default")
            applyDefaultScaling()
            return
        }
        
        let offsetX = instanceResizeWidth * bounds.size.width
        let offsetY = instanceResizeHeight * bounds.size.height
        let newWidth = bounds.size.width + (2 * offsetX)
        let newHeight = bounds.size.height + (2 * offsetY)
        
        if newWidth <= 0 || newHeight <= 0 || newWidth > bounds.size.width * 2 || newHeight > bounds.size.height * 2 {
            print("People.AI calculated dimensions invalid, using default")
            applyDefaultScaling()
            return
        }
        
        let newFrame = NSRect(x: -offsetX, y: -offsetY, width: newWidth, height: newHeight)
        webView?.frame = newFrame
        
        print("People.AI applied validated scaling: frame=\(newFrame)")
    }
    
    private func applyDefaultScaling() {
        webView?.frame = bounds
        if let webView = webView {
            webView.frame.size = webView.convert(bounds.size, from: nil)
        }
        
        print("People.AI applied default scaling: frame=\(bounds)")
    }
    
    // MARK: - Animation Lifecycle
    override func startAnimation() {
        super.startAnimation()
    }
    
    override func stopAnimation() {
        super.stopAnimation()
        
        instanceTimer?.invalidate()
        instanceTimer = nil
        instanceAnimationTimer?.invalidate()
        instanceAnimationTimer = nil
        
        NotificationCenter.default.removeObserver(self)
        
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        
        if #available(macOS 15.0, *) {
            handleMacOS15StopAnimation()
        } else if #available(macOS 10.15, *) {
            handleOlderMacOSStopAnimation()
        }
    }
    
    private func handleMacOS15StopAnimation() {
        if #available(macOS 15.0, *) {
            webView?.evaluateJavaScript("window.stop();", completionHandler: nil)
            webView?.loadHTMLString("", baseURL: nil)
            webView?.evaluateJavaScript("if (window.gc) { window.gc(); }", completionHandler: nil)
        }
    }
    
    private func handleOlderMacOSStopAnimation() {
        if #available(macOS 10.15, *) {
            webView?.loadHTMLString("", baseURL: nil)
            webView?.evaluateJavaScript("window.stop();", completionHandler: nil)
        }
    }
    
    // MARK: - Animation Frame
    override func animateOneFrame() {
        if Self.mdmMode {
            saveCurrentSlide()
        } else {
            if currentSlide < maxSlides {
                animateSlideTransitionWithCompletion {
                    self.currentSlide += 1
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
        let moduleName = Bundle(for: type(of: self)).bundleIdentifier ?? ""
        let defaults = UserDefaults(suiteName: moduleName)
        let viewRefreshTime = defaults?.object(forKey: viewRefreshTimeKey) as? NSNumber
        
        let interval = viewRefreshTime?.doubleValue ?? 0
        if interval >= 1.0 {
            instanceTimer?.invalidate()
            
            instanceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self, !self.isHidden else { return }
                self.loadMdm()
                print("view refreshed.")
            }
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
    
    // MARK: - Background Loading
    private func startBackgroundLoadingOfNextSlide() {
        let nextSlideIndex = (currentSlideIndex + 1) % slides.count
        let nextSlideURL = slides[nextSlideIndex]
        
        if loadingSlides.contains(nextSlideURL) || (slideCache[nextSlideURL] != nil && !isFirstLoop) {
            return
        }
        
        loadingSlides.insert(nextSlideURL)
        
        DispatchQueue.global(qos: .background).async {
            let autoplayURL = self.createAutoplay(link: nextSlideURL, time: Self.stayOnSlideTime?.intValue ?? 0, slide: nextSlideIndex)
            
            guard let nextURL = URL(string: autoplayURL) else { return }
            
            let preloadRequest = URLRequest(url: nextURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30.0)
            
            let task = URLSession.shared.dataTask(with: preloadRequest) { data, response, error in
                DispatchQueue.main.async {
                    self.loadingSlides.remove(nextSlideURL)
                    
                    if error == nil, let data = data {
                        self.slideCache[nextSlideURL] = data
                        print("People.AI cached slide \(nextSlideIndex) in background")
                    } else {
                        print("People.AI failed to preload slide \(nextSlideIndex): \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
            task.resume()
        }
    }
    
    // MARK: - Image Processing
    private func convertToBlurImage(_ image: NSImage) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let inputImage = CIImage(data: tiffData) else { return nil }
        
        let gaussianBlurFilter = CIFilter(name: "CIGaussianBlur")
        gaussianBlurFilter?.setDefaults()
        gaussianBlurFilter?.setValue(inputImage, forKey: kCIInputImageKey)
        gaussianBlurFilter?.setValue(20, forKey: kCIInputRadiusKey)
        
        guard let outputImage = gaussianBlurFilter?.outputImage else { return nil }
        
        if Self.sharedContext == nil {
            Self.sharedContext = CIContext(options: nil)
        }
        
        guard let context = Self.sharedContext,
              let cgimg = context.createCGImage(outputImage, from: inputImage.extent) else { return nil }
        
        let convertedImage = NSImage(cgImage: cgimg, size: NSSize(width: 0, height: 0))
        
        print("People.AI blurred image size: \(convertedImage.size.width) x \(convertedImage.size.height)")
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
                    print("People.AI snapshot size: \(snapshotImage.size.width) x \(snapshotImage.size.height)")
                    let width = self.window?.screen?.frame.size.width ?? 0
                    let height = self.window?.screen?.frame.size.height ?? 0
                    self.imageView = NSImageView(frame: CGRect(x: -width, y: -height, width: width * 3, height: height * 3))
                    print("People.AI web view size: \(self.webView?.bounds.size.width ?? 0) x \(self.webView?.bounds.size.height ?? 0)")
                    if let imageView = self.imageView {
                        self.addSubview(imageView, positioned: .below, relativeTo: self.webView)
                    }
                }
                
                let imageScale: Double = 2
                let resizedImage = snapshotImage.resize(to: CGSize(width: snapshotImage.size.width / imageScale, height: snapshotImage.size.height / imageScale))
                print("People.AI resized size: \(resizedImage.size.width) x \(resizedImage.size.height)")
                
                self.imageView?.image = self.convertToBlurImage(resizedImage)
                self.imageView?.imageScaling = .scaleAxesIndependently
            }
        }
    }
    
    private func setImageBack() {
        if imageView == nil {
            let width = window?.screen?.frame.size.width ?? 0
            let height = window?.screen?.frame.size.height ?? 0
            imageView = NSImageView(frame: CGRect(x: 0, y: 0, width: width, height: height))
            if let imageView = imageView {
                addSubview(imageView, positioned: .below, relativeTo: webView)
            }
        }
        
        if let imageURL = URL(string: Self.emptySpaceFillImage) {
            imageView?.image = NSImage(contentsOf: imageURL)
        }
        print("loading back image - \(Self.emptySpaceFillImage)")
        imageView?.imageScaling = .scaleAxesIndependently
    }
    
    // MARK: - Cleanup
    deinit {
        instanceTimer?.invalidate()
        instanceAnimationTimer?.invalidate()
        
        slideCache.removeAll()
        loadingSlides.removeAll()
        
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        
        if #available(macOS 15.0, *) {
            webView?.loadHTMLString("", baseURL: nil)
            webView?.removeFromSuperview()
        } else if #available(macOS 10.15, *) {
            webView?.loadHTMLString("", baseURL: nil)
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
        let script = "document.body.style = document.body.style.cssText + \";background: transparent !important;\";"
        webView.evaluateJavaScript(script, completionHandler: nil)
        print("People.AI screensaver didFinishNavigation for slide \(currentSlideIndex)")
        
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
                let htmlData = htmlString.data(using: .utf8)
                self.slideCache[slideURL] = htmlData
                print("People.AI cached current slide \(self.currentSlideIndex) content")
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
