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
    BOOL wasHidden = self.isHidden;
    CGFloat wantedLayer = self.wantsLayer;

    self.hidden = NO;
    self.wantsLayer = YES;

    NSImage *image = [[NSImage alloc] initWithSize:self.bounds.size];
    [image lockFocus];
    CGContextRef ctx = [NSGraphicsContext currentContext].graphicsPort;
    [self.layer renderInContext:ctx];
    [image unlockFocus];

    self.wantsLayer = wantedLayer;
    self.hidden = wasHidden;

    return image;    
}

@end
