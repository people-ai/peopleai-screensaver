//
//  NSImage+Resize.h
//  People.ai
//
//  Created by People.ai on 20.10.2021.
//  Copyright © 2021-2022 People.ai. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (Resize)

- (NSImage *)resize:(NSSize)newSize;

@end

NS_ASSUME_NONNULL_END
