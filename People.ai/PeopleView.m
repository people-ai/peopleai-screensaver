//
//  PeopleView.m
//  People.ai
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2022 People.ai, Inc. All rights reserved.
//

#import "PeopleView.h"
#import <QuartzCore/QuartzCore.h>

static BOOL mdmMode = true;
static BOOL debugMode = false;
static BOOL fillEmptySpace = false;
static BOOL dynamic = false;
static NSString *emptySpaceFillMode = @"";
static NSString *emptySpaceFillImage = @"";

static CGFloat resizeWidth = 0.05; // resize
static CGFloat resizeHeight = 0.05; // resize

// Animation properties for smooth slide transitions
static CGFloat slideTransitionDuration = 0.8; // seconds
static NSViewAnimation *currentSlideAnimation;

static NSString *currentLink = @"";
static NSTimer *timer;
static NSNumber *stayOnSlideTime;

static NSTimer *animationTimer;
static CIContext *sharedContext;

// Note: Static variables removed - now using instance properties for multi-desktop support

@implementation PeopleView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        [config setValue:[NSNumber numberWithBool: NO] forKey:@"drawsBackground"];
        
        // Configure for better memory management
        config.processPool = [[WKProcessPool alloc] init];
        config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
        
        // Disable unnecessary features to reduce memory usage
        config.allowsAirPlayForMediaPlayback = NO;
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;
        
        // Enhanced security settings for macOS 15+ with backward compatibility
        if (@available(macOS 15.0, *)) {
            // macOS 15+ specific security enhancements
            WKUserContentController *userContentController = [[WKUserContentController alloc] init];
            config.userContentController = userContentController;
            config.suppressesIncrementalRendering = YES;
            // Note: allowsInlineMediaPlayback is not available in WKWebViewConfiguration
        } else if (@available(macOS 10.15, *)) {
            // macOS 10.15+ compatibility settings
            config.suppressesIncrementalRendering = YES;
        }
        
        self.webView = [[WKWebViewCustom alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height) configuration:config];
        // Enable layer-backed view for smooth animations
        self.webView.wantsLayer = YES;
        [self addSubview:self.webView];
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.autoresizesSubviews = YES;
        self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        if (debugMode) {
            self.textView = [[NSTextView alloc] initWithFrame:CGRectMake(0, 0, 500, 300)];
            [self addSubview:self.textView];
            self.textView.textColor = [NSColor redColor];
            self.textView.backgroundColor = [NSColor whiteColor];
            [self showDebugMessage:[NSString stringWithFormat:@"initial parent view rect: %@", NSStringFromRect(self.frame)]];
            [self showDebugMessage:[NSString stringWithFormat:@"initial web view rect: %@", NSStringFromRect(self.webView.frame)]];
        }
        
        // Register for display change notifications to handle external displays
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(displayConfigurationChanged:)
                                                     name:NSApplicationDidChangeScreenParametersNotification
                                                   object:nil];
        
        
        // Initialize instance-specific slide cache system for multi-desktop support
        self.slideCache = [[NSMutableDictionary alloc] init];
        self.loadingSlides = [[NSMutableSet alloc] init];
        self.currentSlideIndex = 0;
        self.isFirstLoop = YES;
        self.instanceCurrentLink = @"";
        
        // Initialize instance-specific scaling properties
        self.instanceResizeWidth = 0.05;  // Default scaling values
        self.instanceResizeHeight = 0.05;
        self.scalingApplied = NO;
        self.displayDetectionComplete = NO;
        
        if (mdmMode) {
            [self loadMdm];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self checkViewRefreshTime];
                [self setAnimationTimeInterval:1];
            });
        }
    }
    return self;
}

- (void)dealloc {
    // Clean up instance-specific timers
    if (self.instanceTimer) {
        [self.instanceTimer invalidate];
        self.instanceTimer = nil;
    }
    if (self.instanceAnimationTimer) {
        [self.instanceAnimationTimer invalidate];
        self.instanceAnimationTimer = nil;
    }
    
    // Clean up instance-specific resources
    self.slideCache = nil;
    self.loadingSlides = nil;
    self.instanceCurrentLink = nil;
    
    // Clear web view delegate
    self.webView.navigationDelegate = nil;
    
    // Stop any pending network requests
    [self.webView stopLoading];
    
    // Enhanced cleanup for different macOS versions
    if (@available(macOS 15.0, *)) {
        // macOS 15+ specific cleanup
        [self.webView loadHTMLString:@"" baseURL:nil];
        [self.webView removeFromSuperview];
    } else if (@available(macOS 10.15, *)) {
        // macOS 10.15+ cleanup
        [self.webView loadHTMLString:@"" baseURL:nil];
    }
    
}

- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    
    // Handle external display support
    [self updateWebViewForCurrentDisplay];
    
    if (debugMode) {
        [self showDebugMessage:[NSString stringWithFormat:@"setFrame parent view rect: %@", NSStringFromRect(self.frame)]];
        [self showDebugMessage:[NSString stringWithFormat:@"setFrame web view rect: %@", NSStringFromRect(self.webView.frame)]];
        [self showDebugMessage:[NSString stringWithFormat:@"Current display: %@", [self getCurrentDisplayInfo]]];
    }
}

- (void)updateWebViewForCurrentDisplay {
    // Prevent multiple scaling applications
    if (self.scalingApplied) {
        NSLog(@"People.AI scaling already applied, skipping to prevent cumulative effects");
        return;
    }
    
    NSString *moduleName = [NSBundle bundleForClass:self.class].bundleIdentifier;
    NSUserDefaults *def = [[NSUserDefaults alloc] initWithSuiteName:moduleName];
    NSNumber *zoom = [def objectForKey:zoomFullScreenKey];
    
    // Validate bounds before proceeding
    if (self.bounds.size.width <= 0 || self.bounds.size.height <= 0) {
        NSLog(@"People.AI invalid bounds, skipping scaling: %@", NSStringFromRect(self.bounds));
        return;
    }
    
    // Get current screen information with validation
    NSScreen *currentScreen = [self getValidCurrentScreen];
    if (!currentScreen) {
        NSLog(@"People.AI no valid screen detected, using default scaling");
        [self applyDefaultScaling];
        return;
    }
    
    NSRect screenFrame = currentScreen.frame;
    if (screenFrame.size.width <= 0 || screenFrame.size.height <= 0) {
        NSLog(@"People.AI invalid screen dimensions, using default scaling");
        [self applyDefaultScaling];
        return;
    }
    
    CGFloat aspectRatio = screenFrame.size.width / screenFrame.size.height;
    
    if (zoom.boolValue) {
        // Calculate instance-specific scaling based on display characteristics
        [self calculateInstanceScalingForAspectRatio:aspectRatio];
        
        // Apply validated scaling
        [self applyValidatedScaling];
        
        if (debugMode) {
            [self showDebugMessage:[NSString stringWithFormat:@"Instance scaling applied: width=%.3f, height=%.3f, aspect=%.2f", 
                                   self.instanceResizeWidth, self.instanceResizeHeight, aspectRatio]];
        }
    } else {
        [self applyDefaultScaling];
    }
    
    self.scalingApplied = YES;
    self.displayDetectionComplete = YES;
}

- (NSString *)getCurrentDisplayInfo {
    NSScreen *currentScreen = [self.window screen] ?: [NSScreen mainScreen];
    NSRect screenFrame = currentScreen.frame;
    CGFloat aspectRatio = screenFrame.size.width / screenFrame.size.height;
    NSString *orientation = aspectRatio > 1.0 ? @"Horizontal" : @"Vertical";
    
    // Detect ultra-wide displays
    NSString *displayType = @"";
    if (aspectRatio > 2.0) {
        displayType = @" [ULTRA-WIDE]";
    } else if (aspectRatio > 1.5) {
        displayType = @" [WIDE]";
    }
    
    return [NSString stringWithFormat:@"%@ (%@) - %@%@", 
            currentScreen.localizedName ?: @"Unknown Display",
            orientation,
            NSStringFromSize(screenFrame.size),
            displayType];
}

- (void)displayConfigurationChanged:(NSNotification *)notification {
    // Handle external display connection/disconnection with instance-specific handling
    dispatch_async(dispatch_get_main_queue(), ^{
        // Reset scaling state to allow re-detection
        self.scalingApplied = NO;
        self.displayDetectionComplete = NO;
        
        // Delay display detection to prevent race conditions in multi-desktop mode
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self updateWebViewForCurrentDisplay];
            
            if (debugMode) {
                [self showDebugMessage:@"Display configuration changed - updating layout"];
                [self showDebugMessage:[self getCurrentDisplayInfo]];
            }
        });
    });
}

- (void)startAnimation {
    [super startAnimation];
}

- (void)stopAnimation {
    [super stopAnimation];
    
    // Clean up instance-specific timers to prevent memory leaks
    if (self.instanceTimer) {
        [self.instanceTimer invalidate];
        self.instanceTimer = nil;
    }
    if (self.instanceAnimationTimer) {
        [self.instanceAnimationTimer invalidate];
        self.instanceAnimationTimer = nil;
    }
    
    // Clean up slide animation
    if (currentSlideAnimation) {
        [currentSlideAnimation stopAnimation];
        currentSlideAnimation = nil;
    }
    
    // Remove display change notification observer
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Clear web view delegate to prevent retain cycles
    self.webView.navigationDelegate = nil;
    
    // Cancel any pending network requests
    [self.webView stopLoading];
    
    // Enhanced stop animation handling for different macOS versions
    if (@available(macOS 15.0, *)) {
        [self handleMacOS15StopAnimation];
    } else if (@available(macOS 10.15, *)) {
        [self handleOlderMacOSStopAnimation];
    }
}

- (void)handleMacOS15StopAnimation {
    // macOS 15 specific cleanup to prevent background processes
    if (@available(macOS 15.0, *)) {
        // Clear any pending JavaScript execution
        [self.webView evaluateJavaScript:@"window.stop();" completionHandler:nil];
        
        // Clear web view content
        [self.webView loadHTMLString:@"" baseURL:nil];
        
        // Force garbage collection if available
        [self.webView evaluateJavaScript:@"if (window.gc) { window.gc(); }" completionHandler:nil];
    }
}

- (void)handleOlderMacOSStopAnimation {
    // Cleanup for macOS 10.15+ (but not 15+)
    if (@available(macOS 10.15, *)) {
        // Basic cleanup for older versions
        [self.webView loadHTMLString:@"" baseURL:nil];
        
        // Clear any pending JavaScript execution
        [self.webView evaluateJavaScript:@"window.stop();" completionHandler:nil];
    }
}

- (void)drawRect:(NSRect)rect {
    [super drawRect:rect];
}

- (void)animateOneFrame {
    if (mdmMode) {
        [self saveCurrentSlide];
        // For now, just use original logic - don't progress slides automatically
        // The slide progression will be handled by the autoplay functionality
    } else {
        if (self.currentSlide < self.maxSlides) {
            // Animate slide transition first, then change slide
            [self animateSlideTransitionWithCompletion:^{
                self.currentSlide++;
            }];
        } else {
            [self loadInfoMessage:noMoreSlidesError];
        }
    }
}

- (BOOL)hasConfigureSheet {
    return NO;
}

- (void)animateSlideTransitionWithCompletion:(void(^)(void))completion {
    // FIX: Prevent dark screen during transition
    // Ensure WebView remains visible throughout animation
    self.webView.hidden = NO;
    self.webView.alphaValue = 1.0;
    
    // Cancel any existing animation
    if (currentSlideAnimation) {
        [currentSlideAnimation stopAnimation];
        currentSlideAnimation = nil;
    }
    
    // Create smooth slide transition animation
    NSRect currentFrame = self.webView.frame;
    NSRect startFrame = currentFrame;
    NSRect endFrame = currentFrame;
    
    // FIX: Reduced zoom and fade to prevent dark screen
    CGFloat zoomFactor = 1.02; // Reduced from 1.05
    CGFloat fadeAlpha = 0.9;   // Reduced from 0.7 to prevent dark screen
    
    // Set up the animation
    NSDictionary *animationDict = @{
        NSViewAnimationTargetKey: self.webView,
        NSViewAnimationStartFrameKey: [NSValue valueWithRect:startFrame],
        NSViewAnimationEndFrameKey: [NSValue valueWithRect:endFrame],
        NSViewAnimationEffectKey: NSViewAnimationFadeInEffect
    };
    
    currentSlideAnimation = [[NSViewAnimation alloc] initWithViewAnimations:@[animationDict]];
    currentSlideAnimation.duration = slideTransitionDuration * 0.6; // Reduced duration
    currentSlideAnimation.animationCurve = NSAnimationEaseInOut;
    currentSlideAnimation.animationBlockingMode = NSAnimationNonblocking;
    
    // Add a subtle scale animation using Core Animation
    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @(1.0);
    scaleAnimation.toValue = @(zoomFactor);
    scaleAnimation.duration = slideTransitionDuration * 0.3; // Reduced duration
    scaleAnimation.autoreverses = YES;
    scaleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    // Add fade animation with reduced fade
    CABasicAnimation *fadeAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeAnimation.fromValue = @(1.0);
    fadeAnimation.toValue = @(fadeAlpha);
    fadeAnimation.duration = slideTransitionDuration * 0.2; // Reduced duration
    fadeAnimation.autoreverses = YES;
    fadeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    // Apply animations to webView layer
    self.webView.wantsLayer = YES;
    if (self.webView.layer) {
        [self.webView.layer addAnimation:scaleAnimation forKey:@"slideScale"];
        [self.webView.layer addAnimation:fadeAnimation forKey:@"slideFade"];
    }
    
    // Start the animation
    [currentSlideAnimation startAnimation];
    
    // FIX: Shorter animation duration to reduce dark screen time
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(slideTransitionDuration * 0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.webView.layer) {
            [self.webView.layer removeAnimationForKey:@"slideScale"];
            [self.webView.layer removeAnimationForKey:@"slideFade"];
        }
        currentSlideAnimation = nil;
        
        // FIX: Ensure WebView is fully visible after animation
        self.webView.alphaValue = 1.0;
        self.webView.hidden = NO;
        
        // Call completion block
        if (completion) {
            completion();
        }
    });
}

- (NSWindow*)configureSheet {
    return nil;
}

- (void)showDebugMessage:(NSString *)msg {
    NSString *str = [NSString stringWithFormat:@"\nSlides: %@", msg];
    self.textView.string = [self.textView.string stringByAppendingString:str];
}

- (void)saveCurrentSlide {
    NSURLComponents *cmps = [NSURLComponents componentsWithURL:self.webView.URL resolvingAgainstBaseURL:true];
    NSMutableDictionary<NSString *, NSString *> *queryParams = [NSMutableDictionary<NSString *, NSString *> new];
    for (NSURLQueryItem *queryItem in [cmps queryItems]) {
        if (queryItem.value == nil) {
            continue;
        }
        [queryParams setObject:queryItem.value forKey:queryItem.name];
    }
    NSString *strSlide = queryParams[@"slide"];
    if (strSlide != nil) {
        int slide = strSlide.intValue;
        [[NSUserDefaults standardUserDefaults] setInteger:slide forKey:currentSlideKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)checkViewRefreshTime {
    NSString *moduleName = [NSBundle bundleForClass:self.class].bundleIdentifier;
    NSUserDefaults *def = [[NSUserDefaults alloc] initWithSuiteName:moduleName];
    NSNumber *viewRefreshTime = [def objectForKey:viewRefreshTimeKey];
    
    double interval = viewRefreshTime.doubleValue;
    if (interval >= 1.0) {
        // Invalidate existing instance timer to prevent multiple timers
        if (self.instanceTimer) {
            [self.instanceTimer invalidate];
        }
        
        // Use weak reference to prevent retain cycle
        __weak typeof(self) weakSelf = self;
        self.instanceTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && !strongSelf.hidden) {
                [strongSelf loadMdm];
            }
            NSLog(@"view refreshed.");
        }];
    }
}

- (void)loadMdm {
    NSString *moduleName = [NSBundle bundleForClass:self.class].bundleIdentifier;
    NSUserDefaults *def = [[NSUserDefaults alloc] initWithSuiteName:moduleName];
    
    NSString *link = [def stringForKey:urlKey];
    NSNumber *resetSlidesWhenStarted = [def objectForKey:resetKey];
    stayOnSlideTime = [def objectForKey:timeKey];
    NSNumber *zoom = [def objectForKey:zoomFullScreenKey];
    NSNumber *fill = [def objectForKey:fillEmptySpaceKey];
    fillEmptySpace = fill.boolValue;
    NSNumber *dyn = [def objectForKey:dynamicKey];
    dynamic = dyn.boolValue;
    
    emptySpaceFillMode = [def stringForKey:emptySpaceFillModeKey];
    emptySpaceFillImage = [def stringForKey:emptySpaceFillImageKey];
    
    int slide = -1;
    if (resetSlidesWhenStarted.boolValue) {
        slide = 0;
    } else {
        NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:currentSlideKey];
        if (value) {
            slide = value.intValue;
        }
    }
    
    if ((link != nil) && ![link isEqualToString:@""]) {
        // Initialize slides array for background loading
        [self initializeSlidesFromLink:link];
        
        // Use original logic for first slide to ensure it works
        self.instanceCurrentLink = [self createAutoplay:link time:stayOnSlideTime.intValue slide:slide];
        [self setAnimationTimeInterval:stayOnSlideTime.doubleValue]; // Use MDM config directly
        
        NSLog(@"People.AI loading first slide with URL: %@", self.instanceCurrentLink);
        NSLog(@"People.AI slide time: %@ seconds", stayOnSlideTime);
        
        // Create request with timeout to prevent hanging
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:self.instanceCurrentLink] 
                                                    cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                timeoutInterval:30.0];
        self.webView.navigationDelegate = self;
        [self.webView loadRequest:request];
        
        // Start background loading of next slide
        [self startBackgroundLoadingOfNextSlide];
        
        if (zoom.boolValue) {
            // Use the new instance-specific scaling method with delay to prevent race conditions
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self updateWebViewForCurrentDisplay];
            });
        }
    } else {
        [self loadErrorPage];
    }
    
    if (debugMode) {
        [self showDebugMessage:[NSString stringWithFormat:@"loadConfig parent view rect: %@", NSStringFromRect(self.frame)]];
        [self showDebugMessage:[NSString stringWithFormat:@"loadConfig web view rect: %@", NSStringFromRect(self.webView.frame)]];
    }
    
}

// Initialize slides array for background loading
- (void)initializeSlidesFromLink:(NSString *)link {
    // Create slides array from the base link
    NSMutableArray *slidesArray = [NSMutableArray array];
    
    // Add the main link as slide 0
    [slidesArray addObject:link];
    
    // Add variations for different slides (if supported by the service)
    for (int i = 1; i <= 5; i++) {
        NSString *slideURL = [NSString stringWithFormat:@"%@?slide=%d", link, i];
        [slidesArray addObject:slideURL];
    }
    
    self.slides = [slidesArray copy];
    self.currentSlideIndex = 0;
    self.isFirstLoop = YES;
    
    NSLog(@"People.AI initialized %lu slides for background loading", (unsigned long)self.slides.count);
}

- (NSString *)create:(NSString *)link Mode:(NSString *)mode slide:(int)slide {
    return [NSString stringWithFormat:@"%@/preview?rm=%@&slide=%i", link, mode, slide];
}

- (NSString *)createAutoplay:(NSString *)link time:(int)time slide:(int)slide {
    if (slide > 0) {
        return [NSString stringWithFormat:@"%@?rm=minimal&start=true&loop=true&delayms=%d&slide=%i", link, time*1000, slide];
    } else {
        return [NSString stringWithFormat:@"%@?rm=minimal&start=true&loop=true&delayms=%d", link, time*1000];
    }
}

- (void)loadInfoMessage:(NSString *)msg {
    [self.webView loadHTMLString:msg baseURL:nil];
}

- (void)loadErrorPage {
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"error" ofType:@"html"];
    NSURL *url = [NSURL fileURLWithPath:path];
    [self.webView loadFileURL:url allowingReadAccessToURL:url.URLByDeletingLastPathComponent];
}

NSColor *colorAtScreenCoordinate(CGDirectDisplayID displayID, NSInteger x, NSInteger y) {
    CGSize size = CGDisplayScreenSize(displayID);
    CGImageRef image = CGDisplayCreateImageForRect(displayID, CGRectMake(x, y, size.width, size.height));
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSColor *color = [bitmap colorAtX:x y:y];
    CGImageRelease(image);
    return color;
}

CGImageRef getCurrentDisplayImage(CGDirectDisplayID displayID) {
    CGRect rect = CGDisplayBounds(displayID);
    NSLog(@"People.AI display size: %f x %f", rect.size.width, rect.size.height);
    CGImageRef image = CGDisplayCreateImageForRect(displayID, CGRectMake(0, 0, rect.size.width, rect.size.height));
    // Note: Caller is responsible for releasing the returned CGImageRef
    return image;
}

-(NSImage *)convertToBlurImage:(NSImage *)image {
    
    CIImage *inputImage = [CIImage imageWithData:image.TIFFRepresentation];
    
    CIFilter *gaussianBlurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [gaussianBlurFilter setDefaults];
    [gaussianBlurFilter setValue:inputImage forKey:kCIInputImageKey];
    [gaussianBlurFilter setValue:@20 forKey:kCIInputRadiusKey];
    
    CIImage *outputImage = [gaussianBlurFilter outputImage];
    
    // Use shared context to prevent memory leaks
    if (!sharedContext) {
        sharedContext = [CIContext contextWithOptions:nil];
    }
    
    // note, use input image extent if you want it the same size, the output image extent is larger
    CGImageRef cgimg = [sharedContext createCGImage:outputImage fromRect:[inputImage extent]];
    NSImage *convertedImage = [[NSImage alloc] initWithCGImage:cgimg size:NSSizeFromCGSize(CGSizeMake(0, 0))];
    
    // Release the CGImageRef to prevent memory leak
    CGImageRelease(cgimg);
    
    NSLog(@"People.AI blurred image size: %f x %f", convertedImage.size.width, convertedImage.size.height);
    return convertedImage;
}

- (void)performImageUpdate {
    if (@available(macOS 10.13, *)) {
        WKSnapshotConfiguration *wkSnapshotConfig = [WKSnapshotConfiguration new];
        wkSnapshotConfig.snapshotWidth = [NSNumber numberWithInt:self.frame.size.width];
        
        // macOS 15 compatibility: Add error handling and timeout
        [self.webView takeSnapshotWithConfiguration:wkSnapshotConfig completionHandler:^(NSImage * _Nullable snapshotImage, NSError * _Nullable error) {
            if (error) {
                NSLog(@"People.AI snapshot error: %@", error.localizedDescription);
                return;
            }
            
            if (!snapshotImage) {
                NSLog(@"People.AI snapshot failed: No image returned");
                return;
            }
            
            if (self.imageView == nil) {
                NSLog(@"People.AI snapshot size: %f x %f", snapshotImage.size.width, snapshotImage.size.height);
                double width = self.window.screen.frame.size.width;
                double height = self.window.screen.frame.size.height;
                self.imageView = [[NSImageView alloc] initWithFrame:CGRectMake(-width, -height, (width)*3, (height)*3)];
                NSLog(@"People.AI web view size: %f x %f", self.webView.bounds.size.width, self.webView.bounds.size.height);
                [self addSubview:self.imageView positioned:NSWindowBelow relativeTo:self.webView];
            }
            double imageScale = 2;
            NSImage *resizedImage = [snapshotImage resize:CGSizeMake(snapshotImage.size.width/imageScale, snapshotImage.size.height/imageScale)];
            NSLog(@"People.AI resized size : %f x %f", resizedImage.size.width, resizedImage.size.height);
            
            self.imageView.image = [self convertToBlurImage:resizedImage];
            self.imageView.imageScaling = NSImageScaleAxesIndependently;
        }];
    } else {
        // Fallback on earlier versions
    }
}


- (void)setImageBack {
    if (self.imageView == nil) {
        double width = self.window.screen.frame.size.width;
        double height = self.window.screen.frame.size.height;
        self.imageView = [[NSImageView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        [self addSubview:self.imageView positioned:NSWindowBelow relativeTo:self.webView];
    }
    self.imageView.image = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:emptySpaceFillImage]];
    NSLog(@"loading back image - %@", emptySpaceFillImage);
    self.imageView.imageScaling = NSImageScaleAxesIndependently;
}

// MARK: WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"People.AI screensaver navigation failed: %@", error.localizedDescription);
    // Load error page on network failure
    [self loadErrorPage];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"People.AI screensaver provisional navigation failed: %@", error.localizedDescription);
    // Load error page on network failure
    [self loadErrorPage];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
    NSString *script = @"document.body.style = document.body.style.cssText + \";background: transparent !important;\";";
    [self.webView evaluateJavaScript:script completionHandler:nil];
    NSLog(@"People.AI screensaver didFinishNavigation for slide %ld", (long)self.currentSlideIndex);
    
    // Cache the current slide if it's the first loop
    if (self.isFirstLoop && self.currentSlideIndex < self.slides.count) {
        NSString *currentSlideURL = self.slides[self.currentSlideIndex];
        [self cacheCurrentSlideContent:currentSlideURL];
    }
    
    // FIX: Ensure WebView is visible immediately to prevent dark screen
    self.webView.hidden = NO;
    self.webView.alphaValue = 1.0;
    
    if ([emptySpaceFillMode isEqualToString:@"dynamic"]) {
        // Immediate background update for better responsiveness
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self performImageUpdate];
        });
        // Store instance timer reference to prevent memory leaks
        self.instanceAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:stayOnSlideTime.intValue + 1 //1.0
                                         target:self
                                       selector:@selector(performImageUpdate)
                                       userInfo:nil
                                        repeats:YES];
    } else if ([emptySpaceFillMode isEqualToString:@"static"]) {
        if ((emptySpaceFillImage != NULL) && (![emptySpaceFillImage isEqualToString:@""])) {
            [self setImageBack];
        }
    } else if ([emptySpaceFillMode isEqualToString:@"none"]) {
        // no back
    } else {
        // regular
        [self performImageUpdate];
    }
    
}

// MARK: - Slide Animation and Progression

- (void)loadCurrentSlide {
    if (self.currentSlide < self.slides.count) {
        NSString *slideURL = self.slides[self.currentSlide];
        NSURL *url = [NSURL URLWithString:slideURL];
        
        if (url) {
            // FIX: Preload next slide to prevent dark screen
            [self preloadNextSlide];
            
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url 
                                                        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                    timeoutInterval:30.0];
            [self.webView loadRequest:request];
        }
    }
}

// MARK: - New Slide Progression and Background Loading System

- (void)loadCurrentSlideWithBackgroundPreload {
    if (self.currentSlideIndex < self.slides.count) {
        NSString *slideURL = self.slides[self.currentSlideIndex];
        
        // Check if slide is already cached
        if (self.slideCache[slideURL] && !self.isFirstLoop) {
            NSLog(@"People.AI using cached slide %ld", (long)self.currentSlideIndex);
            [self loadCachedSlide:slideURL];
        } else {
            NSLog(@"People.AI loading slide %ld from network", (long)self.currentSlideIndex);
            [self loadSlideFromNetwork:slideURL];
        }
        
        // Start background loading of next slide
        [self startBackgroundLoadingOfNextSlide];
    }
}

- (void)loadCachedSlide:(NSString *)slideURL {
    // Load cached slide content
    NSData *cachedData = self.slideCache[slideURL];
    if (cachedData) {
        NSString *htmlContent = [[NSString alloc] initWithData:cachedData encoding:NSUTF8StringEncoding];
        // Create proper autoplay URL for the base URL
        NSString *autoplayURL = [self createAutoplay:slideURL time:stayOnSlideTime.intValue slide:self.currentSlideIndex];
        [self.webView loadHTMLString:htmlContent baseURL:[NSURL URLWithString:autoplayURL]];
    }
}

- (void)loadSlideFromNetwork:(NSString *)slideURL {
    // Create proper autoplay URL for the slide
    // For slides after the first one, use the slide number from the URL or currentSlideIndex
    int slideNumber = self.currentSlideIndex;
    if (self.currentSlideIndex > 0) {
        slideNumber = self.currentSlideIndex;
    }
    
    NSString *autoplayURL = [self createAutoplay:slideURL time:stayOnSlideTime.intValue slide:slideNumber];
    NSURL *url = [NSURL URLWithString:autoplayURL];
    if (url) {
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url 
                                                    cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                timeoutInterval:30.0];
        self.webView.navigationDelegate = self;
        [self.webView loadRequest:request];
    }
}

- (void)startBackgroundLoadingOfNextSlide {
    NSInteger nextSlideIndex = (self.currentSlideIndex + 1) % self.slides.count;
    NSString *nextSlideURL = self.slides[nextSlideIndex];
    
    // Skip if already loading or cached
    if ([self.loadingSlides containsObject:nextSlideURL] || (self.slideCache[nextSlideURL] && !self.isFirstLoop)) {
        return;
    }
    
    [self.loadingSlides addObject:nextSlideURL];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        // Create proper autoplay URL for background loading
        NSString *autoplayURL = [self createAutoplay:nextSlideURL time:stayOnSlideTime.intValue slide:nextSlideIndex];
        NSURL *nextURL = [NSURL URLWithString:autoplayURL];
        if (nextURL) {
            NSURLRequest *preloadRequest = [[NSURLRequest alloc] initWithURL:nextURL 
                                                                cachePolicy:NSURLRequestReturnCacheDataElseLoad 
                                                            timeoutInterval:30.0];
            
            NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:preloadRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.loadingSlides removeObject:nextSlideURL];
                    
                    if (!error && data) {
                        self.slideCache[nextSlideURL] = data;
                        NSLog(@"People.AI cached slide %ld in background", (long)nextSlideIndex);
                    } else {
                        NSLog(@"People.AI failed to preload slide %ld: %@", (long)nextSlideIndex, error.localizedDescription);
                    }
                });
            }];
            [task resume];
        }
    });
}

- (void)progressToNextSlide {
    // Move to next slide
    self.currentSlideIndex = (self.currentSlideIndex + 1) % self.slides.count;
    
    // Check if we completed first loop
    if (self.currentSlideIndex == 0 && self.isFirstLoop) {
        self.isFirstLoop = NO;
        NSLog(@"People.AI completed first loop, now using cache");
    }
    
    // Load current slide with background preload
    [self loadCurrentSlideWithBackgroundPreload];
}

- (void)cacheCurrentSlideContent:(NSString *)slideURL {
    // Get the HTML content from the web view and cache it
    [self.webView evaluateJavaScript:@"document.documentElement.outerHTML" completionHandler:^(id result, NSError *error) {
        if (!error && [result isKindOfClass:[NSString class]]) {
            NSData *htmlData = [result dataUsingEncoding:NSUTF8StringEncoding];
            self.slideCache[slideURL] = htmlData;
            NSLog(@"People.AI cached current slide %ld content", (long)self.currentSlideIndex);
        }
    }];
}

- (void)preloadNextSlide {
    // Legacy method - now handled by startBackgroundLoadingOfNextSlide
    [self startBackgroundLoadingOfNextSlide];
}

// MARK: - Fixed Scaling System for Multi-Desktop Support

- (NSScreen *)getValidCurrentScreen {
    // Try to get the screen for this instance's window
    NSScreen *currentScreen = nil;
    
    if (self.window && self.window.screen) {
        currentScreen = self.window.screen;
    } else {
        // Fallback to main screen
        currentScreen = [NSScreen mainScreen];
    }
    
    // Validate the screen
    if (currentScreen) {
        NSRect screenFrame = currentScreen.frame;
        if (screenFrame.size.width > 0 && screenFrame.size.height > 0) {
            return currentScreen;
        }
    }
    
    return nil;
}

- (void)calculateInstanceScalingForAspectRatio:(CGFloat)aspectRatio {
    // Reset to default values
    self.instanceResizeWidth = 0.05;
    self.instanceResizeHeight = 0.05;
    
    // Calculate scaling based on display characteristics
    if (aspectRatio > 2.0) {
        // Ultra-wide displays (21:9, 32:9, etc.) - use conservative scaling
        self.instanceResizeWidth = 0.03;
        self.instanceResizeHeight = 0.03;
    } else if (aspectRatio > 1.5) {
        // Wide displays - moderate scaling
        self.instanceResizeWidth = 0.04;
        self.instanceResizeHeight = 0.04;
    } else if (aspectRatio < 0.7) {
        // Vertical displays - conservative scaling
        self.instanceResizeWidth = 0.03;
        self.instanceResizeHeight = 0.03;
    } else {
        // Standard displays - default scaling
        self.instanceResizeWidth = 0.05;
        self.instanceResizeHeight = 0.05;
    }
    
    // Apply strict limits to prevent overscaling
    self.instanceResizeWidth = MIN(self.instanceResizeWidth, 0.01);   // Max 1%
    self.instanceResizeHeight = MIN(self.instanceResizeHeight, 0.01); // Max 1%
    
    NSLog(@"People.AI calculated instance scaling: width=%.3f, height=%.3f for aspect=%.2f", 
          self.instanceResizeWidth, self.instanceResizeHeight, aspectRatio);
}

- (void)applyValidatedScaling {
    // Validate scaling values before applying
    if (self.instanceResizeWidth <= 0 || self.instanceResizeHeight <= 0 ||
        self.instanceResizeWidth > 0.1 || self.instanceResizeHeight > 0.1) {
        NSLog(@"People.AI invalid scaling values, using default");
        [self applyDefaultScaling];
        return;
    }
    
    // Calculate new frame with FIXED scaling formula (no cumulative effects)
    CGFloat offsetX = self.instanceResizeWidth * self.bounds.size.width;
    CGFloat offsetY = self.instanceResizeHeight * self.bounds.size.height;
    CGFloat newWidth = self.bounds.size.width + (2 * offsetX);
    CGFloat newHeight = self.bounds.size.height + (2 * offsetY);
    
    // Validate calculated dimensions
    if (newWidth <= 0 || newHeight <= 0 || newWidth > self.bounds.size.width * 2 || newHeight > self.bounds.size.height * 2) {
        NSLog(@"People.AI calculated dimensions invalid, using default");
        [self applyDefaultScaling];
        return;
    }
    
    // Apply scaling with validated values
    NSRect newFrame = NSMakeRect(-offsetX, -offsetY, newWidth, newHeight);
    [self.webView setFrame:newFrame];
    
    NSLog(@"People.AI applied validated scaling: frame=%@", NSStringFromRect(newFrame));
}

- (void)applyDefaultScaling {
    // Reset to default frame without scaling
    [self.webView setFrame:self.bounds];
    [self.webView setFrameSize:[self.webView convertSize:self.bounds.size fromView:nil]];
    
    NSLog(@"People.AI applied default scaling: frame=%@", NSStringFromRect(self.bounds));
}

@end
