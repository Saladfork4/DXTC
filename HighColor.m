//
//  HighColor.m
//  DXTC
//
//  Created by Saladfork on 10/16/15.
//  Copyright © 2015 Saladfork. All rights reserved.
//

#import "HighColor.h"

@implementation HighColor

-(id)initWithColor:(uint16_t)color {
    self = [super init];
    
    /*
        16-bit color is stored in a 5:6:5 RGB format:
        RRRR RGGG GGGB BBBB
     
        Use masks to extract bits:
        r 0xF800 -> 1111 1000 0000 0000
        g 0x07E0 -> 0000 0111 1110 0000
        b 0x001F -> 0000 0000 0001 1111
     
        Shift red 11 bits to the right.
        Shift green 5 bits to the right.
     */
    _color = color;
    _r5 = (color & 0xF800) >> 11;
    _g6 = (color & 0x07E0) >> 5;
    _b5 = (color & 0x001F);
    
    return self;
}

-(uint32_t)trueColor:(uint8_t)alpha {
    /*
        The 5-bit and 6-bit components must be
        transformed to the 8-bit scale. These
        transformations were taken from an anonymous
        stackoverflow user. :)
     */
    uint8_t r = (_r5 * 527 + 23) >> 6;
    uint8_t g = (_g6 * 259 + 33) >> 6;
    uint8_t b = (_b5 * 527 + 23) >> 6;
    
    return (r << 24) | (g << 16) | (b << 8) | alpha;
}

-(NSColor*)calibratedColor:(uint8_t)alpha gammaCorrection:(CGFloat)power {
    CGFloat red   = powf(_r5/32.0, power);
    CGFloat green = powf(_g6/64.0, power);
    CGFloat blue  = powf(_b5/32.0, power);
    CGFloat alph  = powf(alpha/255.0, power);
    
    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alph];
}

-(id)scale:(CGFloat)factor {
    /*
        All we are doing is multiplying each component by
        the scaling factor and casting it back to an int.
        The MIN and MAX constrain the 5-bit values to [0, 32]
        and the 6-bit values to [0, 64].
     */
    uint8_t r = (uint8_t) (MIN(MAX((CGFloat)_r5 * factor, 0), 32));
    uint8_t g = (uint8_t) (MIN(MAX((CGFloat)_g6 * factor, 0), 64));
    uint8_t b = (uint8_t) (MIN(MAX((CGFloat)_b5 * factor, 0), 32));
    uint16_t result = ((uint16_t)r << 11) | ((uint16_t)g << 5) | b;
    
    return [[HighColor alloc] initWithColor:result];
}

-(id)add:(HighColor*)color {
    uint8_t r = _r5 + [color r5];
    uint8_t g = _g6 + [color g6];
    uint8_t b = _b5 + [color b5];
    uint16_t result = ((uint16_t)r << 11) | ((uint16_t)g << 5) | b;
    
    return [[HighColor alloc] initWithColor:result];
}

-(id)linearBlend:(HighColor*)otherColor {
    HighColor *c0 = [self scale:0.5f];
    HighColor *c1 = [otherColor scale:0.5f];
    return [c0 add:c1];
}

-(id)linearInterpolation:(HighColor*)otherColor {
    HighColor *c0 = [self scale:(2.0f/3.0f)];
    HighColor *c1 = [otherColor scale:(1.0f/3.0f)];
    return [c0 add:c1];
}

@end
