//
//  WKWebViewCustom.m
//  People.ai
//
//  Created by oles on 1/21/20.
//  Copyright © 2020 oles. All rights reserved.
//

#import "WKWebViewCustom.h"

#import <AppKit/AppKit.h>


@implementation WKWebViewCustom

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

- (void)mouseDown:(NSEvent *)theEvent {
    // do nothing to skip any mouse event
}

- (void)keyDown:(NSEvent *)event {
    // do nothing to skip any keyboard event
}

- (void)keyUp:(NSEvent *)event {
    // do nothing to skip any keyboard event
}

@end
