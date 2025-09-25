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
        return nil;
    }
    
    // Validate new size to prevent memory issues
    if (newSize.width <= 0 || newSize.height <= 0 || newSize.width > 10000 || newSize.height > 10000) {
        NSLog(@"Invalid resize dimensions: %@", NSStringFromSize(newSize));
        return nil;
    }
    
    NSImage *smallImage = [[NSImage alloc] initWithSize: newSize];
    [smallImage lockFocus];
    
    // Use a copy to avoid modifying the original image
    NSImage *copyImage = [self copy];
    [copyImage setSize: newSize];
    
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [copyImage drawAtPoint:NSZeroPoint fromRect:CGRectMake(0, 0, newSize.width, newSize.height) operation:NSCompositingOperationCopy fraction:1.0];
    [smallImage unlockFocus];
    
    return smallImage;
}

@end
