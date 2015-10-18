//
//  HighColor.h
//  DXTC
//
//  Created by Saladfork on 10/16/15.
//  Copyright © 2015 Saladfork. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface HighColor : NSObject

@property (readonly) uint8_t r8;
@property (readonly) uint8_t g8;
@property (readonly) uint8_t b8;

/**
 *  Initializes a high-color (16-bit) instance.
 *
 *  - parameter color:      16-bit color 5:6:5 RGB
 *
 *  - returns:  HighColor object.
 */
-(nonnull id)initWithColor:(uint16_t)color;

/**
 *  Returns a NSColor using calibrated hues.
 *
 *  - parameter alpha:              High-color does not store alpha. This field allows
 *                                  you to specify a custom alpha for the NSColor object.
 *
 *  - parameter gammaCorrection:    If the components need to be corrected for a particular
 *                                  gamma value, specify that here. Each color component
 *                                  (besides alpha) will be raised to this power.
 *
 *  - returns:  NSColor object.
 *
 */
-(nonnull NSColor*)calibratedColor:(uint8_t)alpha gammaCorrection:(CGFloat)power;


/**
 *  Computes the linear blend of two colors by averaging the components.
 *
 *  Linear blend => 0.5*c0 + 0.5*c1
 *
 *  - parameter color:      The other color.
 *
 *  - returns: A new HighColor instance.
 */
-(nonnull id)linearBlend:(nonnull HighColor*)color;


/**
 *  Computes the linear interpolation between two colors.
 *
 *  Linear interpolation => (2/3)*c0 + (1/3)*c1
 *
 *  - parameter color:      The other color.
 *
 *  - returns: A new HighColor instance.
 */
-(nonnull id)linearInterpolation:(nonnull HighColor*)color;

@end
