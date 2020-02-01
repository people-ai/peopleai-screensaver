//
//  SlidesView.m
//  Slides
//
//  Created by oles on 1/6/20.
//  Copyright © 2020 oles. All rights reserved.
//

#import "SlidesView.h"

static BOOL mdmMode = true;

@implementation SlidesView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        //[self setAnimationTimeInterval:1/30.0];
        
        self.webView = [[WKWebViewCustom alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        [self addSubview:self.webView];
        self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        if (mdmMode) {
            //[self mdmTest];
            //[self mdmClearForTest];
            [self loadMdm];
        } else {
            [self loadConfiguartionFromBundle];
            [self reloadPage];
        }
        
    }
    return self;
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
        // do nothing
    } else {
        if (self.currentSlide < self.maxSlides) {
            self.currentSlide ++;
            [self reloadPage];
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

- (void)loadMdm {
    NSString *moduleName = [NSBundle bundleForClass:self.class].bundleIdentifier;
    NSUserDefaults *def = [[NSUserDefaults alloc] initWithSuiteName:moduleName];

    NSString *link = [def stringForKey:urlKey];
    //NSNumber *resetSlidesWhenStarted = [def objectForKey:resetKey];
    NSNumber *stayOnSlideTime = [def objectForKey:timeKey];
    NSNumber *zoom = [def objectForKey:zoomFullScreenKey];

    if ((link != nil) && ![link isEqualToString:@""]) {
        NSString *fullLink = [self createAutoplay:link time:stayOnSlideTime.intValue];
        [self setAnimationTimeInterval:self.slideTime/1000]; // from ms to sec
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:fullLink]];
        [self.webView loadRequest:request];
                
        zoom = @(true);
        if (zoom.boolValue) {
            // increase height by 10 %
            CGFloat resizeWidth = 0.05; // resize
            CGFloat resizeHeight = 0.05; // resize

            [self.webView setFrame:NSMakeRect(-(resizeWidth*self.bounds.size.width), -(resizeHeight*self.bounds.size.height), self.bounds.size.width*(1+2*resizeWidth), self.bounds.size.height*(1 + 2 * resizeHeight))];
        }
        
    } else {
        NSString *msg = [NSString stringWithFormat:@"Error: link: %@, time: %@, moduleName: %@", link, stayOnSlideTime, moduleName];
        //[self loadInfoMessage:msg];
        [self loadInfoMessage:msg];
    }
}

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
    [self setAnimationTimeInterval:self.slideTime/1000]; // from ms to sec
}

- (NSString *)create:(NSString *)link Mode:(NSString *)mode slide:(int)slide {
    return [NSString stringWithFormat:@"%@/preview?rm=%@&slide=%i", link, mode, slide];
}

- (NSString *)createAutoplay:(NSString *)link time:(int)time {
    return [NSString stringWithFormat:@"%@?rm=minimal&start=true&loop=true&delayms=%d", link, time];
}

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

- (void)loadInfoMessage:(NSString *)msg {
    [self.webView loadHTMLString:msg baseURL:nil];
}

@end
