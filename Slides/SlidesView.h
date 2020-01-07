//
//  SlidesView.h
//  Slides
//
//  Created by oles on 1/6/20.
//  Copyright © 2020 oles. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>
#import <WebKit/WebKit.h>

const NSString *urlKey = @"slidesUrl";
const NSString *resetKey = @"resetSlidesWhenStarted";
const NSString *timeKey = @"stayOnSlideTime";
const NSString *currentSlideKey = @"currentSlideKey";
const NSString *maxSlidesKey = @"maxSlides";

const NSString *configFile = @"ai.people.screensaver";

const NSString *configError = @"<html><body><b>Error while loading config file</b></body></html>";
const NSString *noMoreSlidesError = @"<html><body><b>No more slides</b></body></html>";

@interface SlidesView : ScreenSaverView

@property (nonatomic, strong) WKWebView *webView;

@property (nonatomic, strong) NSString *baseLink;
@property (nonatomic) int currentSlide;
@property (nonatomic) int maxSlides;
@property (nonatomic) int slideTime;

@end
