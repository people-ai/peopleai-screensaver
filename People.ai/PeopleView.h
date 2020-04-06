//
//  PeopleView.h
//  People.ai
//
//  Created by oles on 1/6/20.
//  Copyright © 2020 oles. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>
#import <WebKit/WebKit.h>

#import "WKWebViewCustom.h"

// Keys

static NSString *urlKey = @"slidesUrl";
static NSString *timeKey = @"stayOnSlideTime";
static NSString *resetKey = @"resetSlidesWhenStarted";
static NSString *currentSlideKey = @"currentSlideKey";
static NSString *maxSlidesKey = @"maxSlides";
static NSString *zoomFullScreenKey = @"zoomForFullScreen";
static NSString *viewRefreshTimeKey = @"viewRefreshTime";


static NSString *configFile = @"ai.people.screensaver";

static NSString *modeMinimal = @"minimal";

// Messages

static NSString *configError = @"<html><body><b>Error while loading config file</b></body></html>";
static NSString *noMoreSlidesError = @"<html><body><b>No more slides</b></body></html>";

@interface PeopleView : ScreenSaverView

@property (nonatomic, strong) WKWebViewCustom *webView;
@property (nonatomic, strong) NSTextView *textView;

@property (nonatomic, strong) NSString *baseLink;
@property (nonatomic) int currentSlide;
@property (nonatomic) int maxSlides;
@property (nonatomic) int slideTime;

@end
