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
    // do nothing
}

- (void)keyDown:(NSEvent *)event {
    // do nothing
}

- (void)keyUp:(NSEvent *)event {
    // do nothing
}

@end
