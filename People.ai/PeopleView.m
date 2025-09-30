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

static CGFloat resizeWidth = 0.05; 
static CGFloat resizeHeight = 0.05; 


static CGFloat slideTransitionDuration = 0.8; 
static NSViewAnimation *currentSlideAnimation;

static NSString *currentLink = @"";
static NSTimer *timer;
static NSNumber *stayOnSlideTime;

static NSTimer *animationTimer;
static CIContext *sharedContext;

@implementation PeopleView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        [config setValue:[NSNumber numberWithBool: NO] forKey:@"drawsBackground"];
        
        
        config.processPool = [[WKProcessPool alloc] init];
        config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
        
        
        config.allowsAirPlayForMediaPlayback = NO;
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;
        
        
        if (@available(macOS 15.0, *)) {
            
            WKUserContentController *userContentController = [[WKUserContentController alloc] init];
            config.userContentController = userContentController;
            config.suppressesIncrementalRendering = YES;
            
        } else if (@available(macOS 10.15, *)) {
            
            config.suppressesIncrementalRendering = YES;
        }
        
        self.webView = [[WKWebViewCustom alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height) configuration:config];
        
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
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(displayConfigurationChanged:)
                                                     name:NSApplicationDidChangeScreenParametersNotification
                                                   object:nil];
        
        
        
        self.slideCache = [[NSMutableDictionary alloc] init];
        self.loadingSlides = [[NSMutableSet alloc] init];
        self.currentSlideIndex = 0;
        self.isFirstLoop = YES;
        self.instanceCurrentLink = @"";
        
        
        self.instanceResizeWidth = 0.05;  
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
    
    if (self.instanceTimer) {
        [self.instanceTimer invalidate];
        self.instanceTimer = nil;
    }
    if (self.instanceAnimationTimer) {
        [self.instanceAnimationTimer invalidate];
        self.instanceAnimationTimer = nil;
    }
    
    
    self.slideCache = nil;
    self.loadingSlides = nil;
    self.instanceCurrentLink = nil;
    
    
    self.webView.navigationDelegate = nil;
    
    
    [self.webView stopLoading];
    
    
    if (@available(macOS 15.0, *)) {
        
        [self.webView loadHTMLString:@"" baseURL:nil];
        [self.webView removeFromSuperview];
    } else if (@available(macOS 10.15, *)) {
        
        [self.webView loadHTMLString:@"" baseURL:nil];
    }
    
}

- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    
    
    [self updateWebViewForCurrentDisplay];
    
    if (debugMode) {
        [self showDebugMessage:[NSString stringWithFormat:@"setFrame parent view rect: %@", NSStringFromRect(self.frame)]];
        [self showDebugMessage:[NSString stringWithFormat:@"setFrame web view rect: %@", NSStringFromRect(self.webView.frame)]];
        [self showDebugMessage:[NSString stringWithFormat:@"Current display: %@", [self getCurrentDisplayInfo]]];
    }
}

- (void)updateWebViewForCurrentDisplay {
    
    if (self.scalingApplied) {
        NSLog(@"People.AI scaling already applied, skipping to prevent cumulative effects");
        return;
    }
    
    NSString *moduleName = [NSBundle bundleForClass:self.class].bundleIdentifier;
    NSUserDefaults *def = [[NSUserDefaults alloc] initWithSuiteName:moduleName];
    NSNumber *zoom = [def objectForKey:zoomFullScreenKey];
    
    
    if (self.bounds.size.width <= 0 || self.bounds.size.height <= 0) {
        NSLog(@"People.AI invalid bounds, skipping scaling: %@", NSStringFromRect(self.bounds));
        return;
    }
    
    
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
        
        [self calculateInstanceScalingForAspectRatio:aspectRatio];
        
        
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.scalingApplied = NO;
        self.displayDetectionComplete = NO;
        
        
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
    
    
    if (self.instanceTimer) {
        [self.instanceTimer invalidate];
        self.instanceTimer = nil;
    }
    if (self.instanceAnimationTimer) {
        [self.instanceAnimationTimer invalidate];
        self.instanceAnimationTimer = nil;
    }
    
    
    if (currentSlideAnimation) {
        [currentSlideAnimation stopAnimation];
        currentSlideAnimation = nil;
    }
    
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    
    self.webView.navigationDelegate = nil;
    
    
    [self.webView stopLoading];
    
    
    if (@available(macOS 15.0, *)) {
        [self handleMacOS15StopAnimation];
    } else if (@available(macOS 10.15, *)) {
        [self handleOlderMacOSStopAnimation];
    }
}

- (void)handleMacOS15StopAnimation {
    
    if (@available(macOS 15.0, *)) {
        
        [self.webView evaluateJavaScript:@"window.stop();" completionHandler:nil];
        
        
        [self.webView loadHTMLString:@"" baseURL:nil];
        
        
        [self.webView evaluateJavaScript:@"if (window.gc) { window.gc(); }" completionHandler:nil];
    }
}

- (void)handleOlderMacOSStopAnimation {
    
    if (@available(macOS 10.15, *)) {
        
        [self.webView loadHTMLString:@"" baseURL:nil];
        
        
        [self.webView evaluateJavaScript:@"window.stop();" completionHandler:nil];
    }
}

- (void)drawRect:(NSRect)rect {
    [super drawRect:rect];
}

- (void)animateOneFrame {
    if (mdmMode) {
        [self saveCurrentSlide];
        
        
    } else {
        if (self.currentSlide < self.maxSlides) {
            
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
    
    
    self.webView.hidden = NO;
    self.webView.alphaValue = 1.0;
    
    
    if (currentSlideAnimation) {
        [currentSlideAnimation stopAnimation];
        currentSlideAnimation = nil;
    }
    
    
    NSRect currentFrame = self.webView.frame;
    NSRect startFrame = currentFrame;
    NSRect endFrame = currentFrame;
    
    
    CGFloat zoomFactor = 1.02; 
    CGFloat fadeAlpha = 0.9;   
    
    
    NSDictionary *animationDict = @{
        NSViewAnimationTargetKey: self.webView,
        NSViewAnimationStartFrameKey: [NSValue valueWithRect:startFrame],
        NSViewAnimationEndFrameKey: [NSValue valueWithRect:endFrame],
        NSViewAnimationEffectKey: NSViewAnimationFadeInEffect
    };
    
    currentSlideAnimation = [[NSViewAnimation alloc] initWithViewAnimations:@[animationDict]];
    currentSlideAnimation.duration = slideTransitionDuration * 0.6; 
    currentSlideAnimation.animationCurve = NSAnimationEaseInOut;
    currentSlideAnimation.animationBlockingMode = NSAnimationNonblocking;
    
    
    CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation.fromValue = @(1.0);
    scaleAnimation.toValue = @(zoomFactor);
    scaleAnimation.duration = slideTransitionDuration * 0.3; 
    scaleAnimation.autoreverses = YES;
    scaleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    
    CABasicAnimation *fadeAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeAnimation.fromValue = @(1.0);
    fadeAnimation.toValue = @(fadeAlpha);
    fadeAnimation.duration = slideTransitionDuration * 0.2; 
    fadeAnimation.autoreverses = YES;
    fadeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    
    self.webView.wantsLayer = YES;
    if (self.webView.layer) {
        [self.webView.layer addAnimation:scaleAnimation forKey:@"slideScale"];
        [self.webView.layer addAnimation:fadeAnimation forKey:@"slideFade"];
    }
    
    
    [currentSlideAnimation startAnimation];
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(slideTransitionDuration * 0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.webView.layer) {
            [self.webView.layer removeAnimationForKey:@"slideScale"];
            [self.webView.layer removeAnimationForKey:@"slideFade"];
        }
        currentSlideAnimation = nil;
        
        
        self.webView.alphaValue = 1.0;
        self.webView.hidden = NO;
        
        
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
        
        if (self.instanceTimer) {
            [self.instanceTimer invalidate];
        }
        
        
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
        
        [self initializeSlidesFromLink:link];
        
        
        self.instanceCurrentLink = [self createAutoplay:link time:stayOnSlideTime.intValue slide:slide];
        [self setAnimationTimeInterval:stayOnSlideTime.doubleValue]; 
        
        NSLog(@"People.AI loading first slide with URL: %@", self.instanceCurrentLink);
        NSLog(@"People.AI slide time: %@ seconds", stayOnSlideTime);
        
        
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:self.instanceCurrentLink] 
                                                    cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                timeoutInterval:30.0];
        self.webView.navigationDelegate = self;
        [self.webView loadRequest:request];
        
        
        [self startBackgroundLoadingOfNextSlide];
        
        if (zoom.boolValue) {
            
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


- (void)initializeSlidesFromLink:(NSString *)link {
    
    NSMutableArray *slidesArray = [NSMutableArray array];
    
    
    [slidesArray addObject:link];
    
    
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
    
    return image;
}

-(NSImage *)convertToBlurImage:(NSImage *)image {
    
    CIImage *inputImage = [CIImage imageWithData:image.TIFFRepresentation];
    
    CIFilter *gaussianBlurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [gaussianBlurFilter setDefaults];
    [gaussianBlurFilter setValue:inputImage forKey:kCIInputImageKey];
    [gaussianBlurFilter setValue:@20 forKey:kCIInputRadiusKey];
    
    CIImage *outputImage = [gaussianBlurFilter outputImage];
    
    
    if (!sharedContext) {
        sharedContext = [CIContext contextWithOptions:nil];
    }
    
    
    CGImageRef cgimg = [sharedContext createCGImage:outputImage fromRect:[inputImage extent]];
    NSImage *convertedImage = [[NSImage alloc] initWithCGImage:cgimg size:NSSizeFromCGSize(CGSizeMake(0, 0))];
    
    
    CGImageRelease(cgimg);
    
    NSLog(@"People.AI blurred image size: %f x %f", convertedImage.size.width, convertedImage.size.height);
    return convertedImage;
}

- (void)performImageUpdate {
    if (@available(macOS 10.13, *)) {
        WKSnapshotConfiguration *wkSnapshotConfig = [WKSnapshotConfiguration new];
        wkSnapshotConfig.snapshotWidth = [NSNumber numberWithInt:self.frame.size.width];
        
        
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



- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"People.AI screensaver navigation failed: %@", error.localizedDescription);
    
    [self loadErrorPage];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"People.AI screensaver provisional navigation failed: %@", error.localizedDescription);
    
    [self loadErrorPage];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
    NSString *script = @"document.body.style = document.body.style.cssText + \";background: transparent !important;\";";
    [self.webView evaluateJavaScript:script completionHandler:nil];
    NSLog(@"People.AI screensaver didFinishNavigation for slide %ld", (long)self.currentSlideIndex);
    
    
    if (self.isFirstLoop && self.currentSlideIndex < self.slides.count) {
        NSString *currentSlideURL = self.slides[self.currentSlideIndex];
        [self cacheCurrentSlideContent:currentSlideURL];
    }
    
    
    self.webView.hidden = NO;
    self.webView.alphaValue = 1.0;
    
    if ([emptySpaceFillMode isEqualToString:@"dynamic"]) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self performImageUpdate];
        });
        
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
        
    } else {
        
        [self performImageUpdate];
    }
    
}



- (void)loadCurrentSlide {
    if (self.currentSlide < self.slides.count) {
        NSString *slideURL = self.slides[self.currentSlide];
        NSURL *url = [NSURL URLWithString:slideURL];
        
        if (url) {
            
            [self preloadNextSlide];
            
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url 
                                                        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                    timeoutInterval:30.0];
            [self.webView loadRequest:request];
        }
    }
}



- (void)loadCurrentSlideWithBackgroundPreload {
    if (self.currentSlideIndex < self.slides.count) {
        NSString *slideURL = self.slides[self.currentSlideIndex];
        
        
        if (self.slideCache[slideURL] && !self.isFirstLoop) {
            NSLog(@"People.AI using cached slide %ld", (long)self.currentSlideIndex);
            [self loadCachedSlide:slideURL];
        } else {
            NSLog(@"People.AI loading slide %ld from network", (long)self.currentSlideIndex);
            [self loadSlideFromNetwork:slideURL];
        }
        
        
        [self startBackgroundLoadingOfNextSlide];
    }
}

- (void)loadCachedSlide:(NSString *)slideURL {
    
    NSData *cachedData = self.slideCache[slideURL];
    if (cachedData) {
        NSString *htmlContent = [[NSString alloc] initWithData:cachedData encoding:NSUTF8StringEncoding];
        
        NSString *autoplayURL = [self createAutoplay:slideURL time:stayOnSlideTime.intValue slide:self.currentSlideIndex];
        [self.webView loadHTMLString:htmlContent baseURL:[NSURL URLWithString:autoplayURL]];
    }
}

- (void)loadSlideFromNetwork:(NSString *)slideURL {
    
    
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
    
    
    if ([self.loadingSlides containsObject:nextSlideURL] || (self.slideCache[nextSlideURL] && !self.isFirstLoop)) {
        return;
    }
    
    [self.loadingSlides addObject:nextSlideURL];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
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
    
    self.currentSlideIndex = (self.currentSlideIndex + 1) % self.slides.count;
    
    
    if (self.currentSlideIndex == 0 && self.isFirstLoop) {
        self.isFirstLoop = NO;
        NSLog(@"People.AI completed first loop, now using cache");
    }
    
    
    [self loadCurrentSlideWithBackgroundPreload];
}

- (void)cacheCurrentSlideContent:(NSString *)slideURL {
    
    [self.webView evaluateJavaScript:@"document.documentElement.outerHTML" completionHandler:^(id result, NSError *error) {
        if (!error && [result isKindOfClass:[NSString class]]) {
            NSData *htmlData = [result dataUsingEncoding:NSUTF8StringEncoding];
            self.slideCache[slideURL] = htmlData;
            NSLog(@"People.AI cached current slide %ld content", (long)self.currentSlideIndex);
        }
    }];
}

- (void)preloadNextSlide {
    
    [self startBackgroundLoadingOfNextSlide];
}



- (NSScreen *)getValidCurrentScreen {
    
    NSScreen *currentScreen = nil;
    
    if (self.window && self.window.screen) {
        currentScreen = self.window.screen;
    } else {
        
        currentScreen = [NSScreen mainScreen];
    }
    
    
    if (currentScreen) {
        NSRect screenFrame = currentScreen.frame;
        if (screenFrame.size.width > 0 && screenFrame.size.height > 0) {
            return currentScreen;
        }
    }
    
    return nil;
}

- (void)calculateInstanceScalingForAspectRatio:(CGFloat)aspectRatio {
    
    self.instanceResizeWidth = 0.05;
    self.instanceResizeHeight = 0.05;
    
    
    if (aspectRatio > 2.0) {
        
        self.instanceResizeWidth = 0.03;
        self.instanceResizeHeight = 0.03;
    } else if (aspectRatio > 1.5) {
        
        self.instanceResizeWidth = 0.04;
        self.instanceResizeHeight = 0.04;
    } else if (aspectRatio < 0.7) {
        
        self.instanceResizeWidth = 0.03;
        self.instanceResizeHeight = 0.03;
    } else {
        
        self.instanceResizeWidth = 0.05;
        self.instanceResizeHeight = 0.05;
    }
    
    
    self.instanceResizeWidth = MIN(self.instanceResizeWidth, 0.01);   
    self.instanceResizeHeight = MIN(self.instanceResizeHeight, 0.01); 
    
    NSLog(@"People.AI calculated instance scaling: width=%.3f, height=%.3f for aspect=%.2f", 
          self.instanceResizeWidth, self.instanceResizeHeight, aspectRatio);
}

- (void)applyValidatedScaling {
    
    if (self.instanceResizeWidth <= 0 || self.instanceResizeHeight <= 0 ||
        self.instanceResizeWidth > 0.1 || self.instanceResizeHeight > 0.1) {
        NSLog(@"People.AI invalid scaling values, using default");
        [self applyDefaultScaling];
        return;
    }
    
    
    CGFloat offsetX = self.instanceResizeWidth * self.bounds.size.width;
    CGFloat offsetY = self.instanceResizeHeight * self.bounds.size.height;
    CGFloat newWidth = self.bounds.size.width + (2 * offsetX);
    CGFloat newHeight = self.bounds.size.height + (2 * offsetY);
    
    
    if (newWidth <= 0 || newHeight <= 0 || newWidth > self.bounds.size.width * 2 || newHeight > self.bounds.size.height * 2) {
        NSLog(@"People.AI calculated dimensions invalid, using default");
        [self applyDefaultScaling];
        return;
    }
    
    
    NSRect newFrame = NSMakeRect(-offsetX, -offsetY, newWidth, newHeight);
    [self.webView setFrame:newFrame];
    
    NSLog(@"People.AI applied validated scaling: frame=%@", NSStringFromRect(newFrame));
}

- (void)applyDefaultScaling {
    
    [self.webView setFrame:self.bounds];
    [self.webView setFrameSize:[self.webView convertSize:self.bounds.size fromView:nil]];
    
    NSLog(@"People.AI applied default scaling: frame=%@", NSStringFromRect(self.bounds));
}

@end
