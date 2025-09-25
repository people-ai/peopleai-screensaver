//
//  NSView+ImageRepresentation.m
//  People.ai
//
//  Created by People.ai on 17.10.2021.
//  Copyright © 2021-2022 People.ai. All rights reserved.
//

#import "NSView+ImageRepresentation.h"

@implementation NSView (ImageRepresentation)

- (NSImage *)imageRepresentation
{
    // Validate bounds to prevent memory issues
    if (self.bounds.size.width <= 0 || self.bounds.size.height <= 0) {
        NSLog(@"Invalid view bounds for image representation: %@", NSStringFromRect(self.bounds));
        return nil;
    }
    
    BOOL wasHidden = self.isHidden;
    CGFloat wantedLayer = self.wantsLayer;

    self.hidden = NO;
    self.wantsLayer = YES;

    NSImage *image = [[NSImage alloc] initWithSize:self.bounds.size];
    [image lockFocus];
    
    @try {
        CGContextRef ctx = [NSGraphicsContext currentContext].CGContext;
        if (ctx && self.layer) {
            [self.layer renderInContext:ctx];
        }
    } @catch (NSException *exception) {
        NSLog(@"Error rendering view to image: %@", exception.reason);
    } @finally {
        [image unlockFocus];
    }

    self.wantsLayer = wantedLayer;
    self.hidden = wasHidden;

    return image;    
}

@end
