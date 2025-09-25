//
//  PeopleView.m
//  People.ai
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2022 People.ai, Inc. All rights reserved.
//

#import "PeopleView.h"

static BOOL mdmMode = true;
static BOOL debugMode = false;
static BOOL fillEmptySpace = false;
static BOOL dynamic = false;
static NSString *emptySpaceFillMode = @"";
static NSString *emptySpaceFillImage = @"";

static CGFloat resizeWidth = 0.05; // resize
static CGFloat resizeHeight = 0.05; // resize

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
    // Clean up timers
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
    if (animationTimer) {
        [animationTimer invalidate];
        animationTimer = nil;
    }
    
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
    
    NSString *moduleName = [NSBundle bundleForClass:self.class].bundleIdentifier;
    NSUserDefaults *def = [[NSUserDefaults alloc] initWithSuiteName:moduleName];
    NSNumber *zoom = [def objectForKey:zoomFullScreenKey];
    
    if (zoom.boolValue) {
        [self.webView setFrame:NSMakeRect(-(resizeWidth*self.bounds.size.width), -(resizeHeight*self.bounds.size.height), self.bounds.size.width*(1+2*resizeWidth), self.bounds.size.height*(1 + 2 * resizeHeight))];
    } else {
        [self.webView setFrame:frameRect];
        [self.webView setFrameSize:[self.webView convertSize:frameRect.size fromView:nil]];
    }
    
    if (debugMode) {
        [self showDebugMessage:[NSString stringWithFormat:@"setFrame parent view rect: %@", NSStringFromRect(self.frame)]];
        [self showDebugMessage:[NSString stringWithFormat:@"setFrame web view rect: %@", NSStringFromRect(self.webView.frame)]];
    }
}

- (void)startAnimation {
    [super startAnimation];
}

- (void)stopAnimation {
    [super stopAnimation];
    
    // Clean up timers to prevent memory leaks
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
    if (animationTimer) {
        [animationTimer invalidate];
        animationTimer = nil;
    }
    
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
    } else {
        if (self.currentSlide < self.maxSlides) {
            self.currentSlide ++;
        } else {
            [self loadInfoMessage:noMoreSlidesError];
        }
    }
}

- (BOOL)hasConfigureSheet {
    return NO;
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
        // Invalidate existing timer to prevent multiple timers
        if (timer) {
            [timer invalidate];
        }
        
        // Use weak reference to prevent retain cycle
        __weak typeof(self) weakSelf = self;
        timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
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
        currentLink = [self createAutoplay:link time:stayOnSlideTime.intValue slide:slide];
        [self setAnimationTimeInterval:self.slideTime]; // from ms to sec
        
        // Create request with timeout to prevent hanging
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:currentLink] 
                                                    cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                timeoutInterval:30.0];
        self.webView.navigationDelegate = self;
        [self.webView loadRequest:request];
        
        if (zoom.boolValue) {
            [self.webView setFrame:NSMakeRect(-(resizeWidth*self.bounds.size.width), -(resizeHeight*self.bounds.size.height), self.bounds.size.width*(1+2*resizeWidth), self.bounds.size.height*(1 + 2 * resizeHeight))];
        }
    } else {
        [self loadErrorPage];
    }
    
    if (debugMode) {
        [self showDebugMessage:[NSString stringWithFormat:@"loadConfig parent view rect: %@", NSStringFromRect(self.frame)]];
        [self showDebugMessage:[NSString stringWithFormat:@"loadConfig web view rect: %@", NSStringFromRect(self.webView.frame)]];
    }
    
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
    NSLog(@"People.AI screensaver didFinishNavigation");
    
    if ([emptySpaceFillMode isEqualToString:@"dynamic"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self performImageUpdate];
        });
        // Store timer reference to prevent memory leaks
        animationTimer = [NSTimer scheduledTimerWithTimeInterval:stayOnSlideTime.intValue + 1 //1.0
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

@end
