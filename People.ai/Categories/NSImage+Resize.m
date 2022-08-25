//
//  NSImage+Resize.m
//  People.ai
//
//  Created by People.ai on 20.10.2021.
//  Copyright © 2021-2022 People.ai. All rights reserved.
//

#import "NSImage+Resize.h"

@implementation NSImage (Resize)

- (NSImage *)resize:(NSSize)newSize {
    if (![self isValid]){
        NSLog(@"Invalid Image");
    } else {
        NSImage *smallImage = [[NSImage alloc] initWithSize: newSize];
        [smallImage lockFocus];
        [self setSize: newSize];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [self drawAtPoint:NSZeroPoint fromRect:CGRectMake(0, 0, newSize.width, newSize.height) operation:NSCompositingOperationCopy fraction:1.0];
        [smallImage unlockFocus];
        return smallImage;
    }
    return nil;
}

@end
