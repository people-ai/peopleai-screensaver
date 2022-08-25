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

@implementation PeopleView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        [config setValue:[NSNumber numberWithBool: NO] forKey:@"drawsBackground"];
        
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
        timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
            if (!self.hidden) {
                [self loadMdm];
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
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:currentLink]];
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
    return image;
}

-(NSImage *)convertToBlurImage:(NSImage *)image {
    
    CIImage *inputImage = [CIImage imageWithData:image.TIFFRepresentation];
    
    CIFilter *gaussianBlurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [gaussianBlurFilter setDefaults];
    [gaussianBlurFilter setValue:inputImage forKey:kCIInputImageKey];
    [gaussianBlurFilter setValue:@20 forKey:kCIInputRadiusKey];
    
    CIImage *outputImage = [gaussianBlurFilter outputImage];
    CIContext *context   = [CIContext contextWithOptions:nil];
    // note, use input image extent if you want it the same size, the output image extent is larger
    CGImageRef cgimg     = [context createCGImage:outputImage fromRect:[inputImage extent]];
    NSImage *convertedImage = [[NSImage alloc] initWithCGImage:cgimg size:NSSizeFromCGSize(CGSizeMake(0, 0))];
    NSLog(@"People.AI blurred image size: %f x %f", convertedImage.size.width, convertedImage.size.height);
    return convertedImage;
}

- (void)performImageUpdate {
    if (@available(macOS 10.13, *)) {
        WKSnapshotConfiguration *wkSnapshotConfig = [WKSnapshotConfiguration new];
        wkSnapshotConfig.snapshotWidth = [NSNumber numberWithInt:self.frame.size.width];
        [self.webView takeSnapshotWithConfiguration:wkSnapshotConfig completionHandler:^(NSImage * _Nullable snapshotImage, NSError * _Nullable error) {
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

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
    NSString *script = @"document.body.style = document.body.style.cssText + \";background: transparent !important;\";";
    [self.webView evaluateJavaScript:script completionHandler:nil];
    NSLog(@"People.AI screensaver didFinishNavigation");
    
    if ([emptySpaceFillMode isEqualToString:@"dynamic"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self performImageUpdate];
        });
        [NSTimer scheduledTimerWithTimeInterval:stayOnSlideTime.intValue + 1 //1.0
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
