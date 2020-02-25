//
//  SlidesView.m
//  People.ai Screensaver
//
//  Created by George Kozlov on 1/6/20.
//  Copyright © 2020 People.ai. All rights reserved.
//

#import "SlidesView.h"

static BOOL mdmMode = true;
static BOOL debugMode = false;

static CGFloat resizeWidth = 0.05; // resize
static CGFloat resizeHeight = 0.05; // resize

static NSString *currentLink = @"";
static int previousSlide = 0;
static NSTimer *timer;

@implementation SlidesView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        //[self setAnimationTimeInterval:1/30.0];
        
        self.webView = [[WKWebViewCustom alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
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
        } else {
            //[self loadConfiguartionFromBundle];
            //[self reloadPage];
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
        // do nothing, just save current slide
        [self saveCurrentSlide];
    } else {
        if (self.currentSlide < self.maxSlides) {
            self.currentSlide ++;
            //[self reloadPage];
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

    int interval = viewRefreshTime.intValue;
    timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
        [self loadMdm];
        NSLog(@"view refreshed.");
    }];
}

- (void)loadMdm {
    NSString *moduleName = [NSBundle bundleForClass:self.class].bundleIdentifier;
    NSUserDefaults *def = [[NSUserDefaults alloc] initWithSuiteName:moduleName];

    NSString *link = [def stringForKey:urlKey];
    NSNumber *resetSlidesWhenStarted = [def objectForKey:resetKey];
    NSNumber *stayOnSlideTime = [def objectForKey:timeKey];
    NSNumber *zoom = [def objectForKey:zoomFullScreenKey];

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
        [self.webView loadRequest:request];
                
        if (zoom.boolValue) {
            [self.webView setFrame:NSMakeRect(-(resizeWidth*self.bounds.size.width), -(resizeHeight*self.bounds.size.height), self.bounds.size.width*(1+2*resizeWidth), self.bounds.size.height*(1 + 2 * resizeHeight))];
        }
        
    } else {
        NSString *msg = [NSString stringWithFormat:@"Error: link: %@, time: %@, moduleName: %@", link, stayOnSlideTime, moduleName];
        //[self loadInfoMessage:msg];
        [self loadInfoMessage:msg];
    }
    
    if (debugMode) {
        [self showDebugMessage:[NSString stringWithFormat:@"loadConfig parent view rect: %@", NSStringFromRect(self.frame)]];
        [self showDebugMessage:[NSString stringWithFormat:@"loadConfig web view rect: %@", NSStringFromRect(self.webView.frame)]];
    }

}

/*
- (void)loadConfiguartionFromBundle {
    NSDictionary *mainConfiguration = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.test.Slides"] pathForResource:configFile ofType:@"plist" inDirectory:@""]];

    NSString *link = mainConfiguration[urlKey];
    NSNumber *resetSlidesWhenStarted = mainConfiguration[resetKey];
    NSNumber *stayOnSlideTime = mainConfiguration[timeKey];
    NSNumber *max = mainConfiguration[maxSlidesKey];
    
    if (resetSlidesWhenStarted && resetSlidesWhenStarted.boolValue) {
        self.currentSlide = 0;
    } else {
        NSNumber *slide = [[NSUserDefaults standardUserDefaults] objectForKey:currentSlideKey];
        if (slide) {
            self.currentSlide = slide.intValue;
        } else {
            self.currentSlide = 0;
        }
    }
    self.maxSlides = 3;
    if (link) {
        self.baseLink = link;
        self.slideTime = stayOnSlideTime.intValue;
        self.maxSlides = max.intValue;
    } else {
        // show some default image or text
        [self loadInfoMessage:configError];
    }
    [self setAnimationTimeInterval:self.slideTime]; // from ms to sec
}
*/

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

/*
- (void)reloadPage {
    if (self.baseLink) {
        NSString *link = [self create:self.baseLink Mode:modeMinimal slide:self.currentSlide];
        if (link) {
            NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:link]];
            [self.webView loadRequest:request];
        }
        [[NSUserDefaults standardUserDefaults] setObject:@(self.currentSlide) forKey:currentSlideKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
*/

- (void)loadInfoMessage:(NSString *)msg {
    [self.webView loadHTMLString:msg baseURL:nil];
}

@end
