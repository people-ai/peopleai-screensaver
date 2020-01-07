//
//  SlidesView.m
//  Slides
//
//  Created by oles on 1/6/20.
//  Copyright © 2020 oles. All rights reserved.
//

#import "SlidesView.h"

@implementation SlidesView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        //[self setAnimationTimeInterval:1/30.0];
        
        self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        [self addSubview:self.webView];
        
        [self loadConfiguartion];
        [self reloadPage];
        
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
    // do nothing
    if (self.currentSlide < self.maxSlides) {
        self.currentSlide ++;
        [self reloadPage];
    } else {
        [self loadInfoMessage:noMoreSlidesError];
    }
}

- (BOOL)hasConfigureSheet {
    return NO;
}

- (NSWindow*)configureSheet {
    return nil;
}

- (void)loadConfiguartion {
    NSDictionary *mainConfiguration = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle bundleWithIdentifier:@"com.test.Slides"] pathForResource:configFile ofType:@"plist" inDirectory:@""]];

    NSString *link = mainConfiguration[urlKey];
    NSNumber *resetSlidesWhenStarted = mainConfiguration[resetKey];
    NSNumber *stayOnSlideTime = mainConfiguration[timeKey];
    NSNumber *max = mainConfiguration[maxSlidesKey];
    
    if (resetSlidesWhenStarted.boolValue) {
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

- (void)reloadPage {
    if (self.baseLink) {
        NSString *link = [self create:self.baseLink Mode:@"minimal" slide:self.currentSlide];
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
