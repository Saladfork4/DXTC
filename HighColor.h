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

@property (readonly) uint16_t color;
@property (readonly) uint8_t r5;
@property (readonly) uint8_t g6;
@property (readonly) uint8_t b5;

/**
 *  Initializes a high-color (16-bit) instance.
 *
 *  - parameter color:      16-bit color 5:6:5 RGB
 *
 *  - returns:  HighColor object.
 */
-(nonnull id)initWithColor:(uint16_t)color;


/**
 *  Returns the true-color (32-bit) equivalent of the stored color.
 *
 *  - parameter alpha:      High-color does not store alpha. This field allows
 *                          you to specify a custom alpha.
 *
 *  - returns:  32-bit RGBA integer.
 */
-(uint32_t)trueColor:(uint8_t)alpha;


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
 *  Scales the color by a float and returns a new instance.
 *
 *  - parameter factor:     Scale-factor. This is done per-component, not on the
 *                          color itself. For example, a factor of '2' would scale
 *                          the red, green, and blue components by '2' respectively.
 *
 *  - returns: A new HighColor instance.
 */
-(nonnull id)scale:(CGFloat)factor;


/**
 *  Adds two HighColor objects and returns a new instance.
 *
 *  - parameter color:      The other color. Addition is done per-component.
 *
 *  - returns: A new HighColor instance.
 */
-(nonnull id)add:(nonnull HighColor*)color;


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
