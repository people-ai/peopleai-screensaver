//
//  PeopleView.h
//  People.ai
//
//  Created by People.ai on 1/6/20.
//  Copyright © 2020-2022 People.ai, Inc. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>
#import <WebKit/WebKit.h>
#import <CoreImage/CoreImage.h>
#import "WKWebViewCustom.h"
#include "NSView+ImageRepresentation.h"
#include "NSImage+Resize.h"

// Keys

static NSString *urlKey = @"slidesUrl";
static NSString *timeKey = @"stayOnSlideTime";
static NSString *resetKey = @"resetSlidesWhenStarted";
static NSString *currentSlideKey = @"currentSlideKey";
static NSString *maxSlidesKey = @"maxSlides";
static NSString *zoomFullScreenKey = @"zoomForFullScreen";
static NSString *viewRefreshTimeKey = @"viewRefreshTime";
static NSString *fillEmptySpaceKey = @"fillEmptySpace";
static NSString *dynamicKey = @"dynamic";
static NSString *emptySpaceFillImageKey = @"emptySpaceFillImage";
static NSString *emptySpaceFillModeKey = @"emptySpaceFillMode";

static NSString *configFile = @"ai.people.screensaver";

static NSString *modeMinimal = @"minimal";

// Messages

static NSString *configError = @"<html><body><b>Error while loading config file</b></body></html>";
static NSString *noMoreSlidesError = @"<html><body><b>No more slides</b></body></html>";

@interface PeopleView : ScreenSaverView<WKNavigationDelegate>

@property (nonatomic, strong) WKWebViewCustom *webView;
@property (nonatomic, strong) NSTextView *textView;

@property (nonatomic, strong) NSImageView *imageView;

@property (nonatomic, strong) NSString *baseLink;
@property (nonatomic) int currentSlide;
@property (nonatomic) int maxSlides;
@property (nonatomic) int slideTime;
@property (nonatomic, strong) NSArray<NSString *> *slides;

// Instance-specific slide management properties (replacing static variables)
@property (nonatomic, strong) NSMutableDictionary *slideCache;
@property (nonatomic, strong) NSMutableSet *loadingSlides;
@property (nonatomic) NSInteger currentSlideIndex;
@property (nonatomic) BOOL isFirstLoop;
@property (nonatomic, strong) NSTimer *instanceTimer;
@property (nonatomic, strong) NSTimer *instanceAnimationTimer;
@property (nonatomic, strong) NSString *instanceCurrentLink;

// Instance-specific scaling properties (replacing static variables)
@property (nonatomic) CGFloat instanceResizeWidth;
@property (nonatomic) CGFloat instanceResizeHeight;
@property (nonatomic) BOOL scalingApplied;
@property (nonatomic) BOOL displayDetectionComplete;

// Method declarations for macOS version compatibility
- (void)handleMacOS15StopAnimation;
- (void)handleOlderMacOSStopAnimation;

// Slide transition animation
- (void)animateSlideTransitionWithCompletion:(void(^)(void))completion;

// External display support
- (void)updateWebViewForCurrentDisplay;
- (NSString *)getCurrentDisplayInfo;
- (void)displayConfigurationChanged:(NSNotification *)notification;

// Slide management methods
- (void)loadCurrentSlide;
- (void)preloadNextSlide;
- (void)initializeSlidesFromLink:(NSString *)link;

@end
