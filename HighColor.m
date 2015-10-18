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
     
        r -> 1111 1000 0000 0000
        g -> 0000 0111 1110 0000
        b -> 0000 0000 0001 1111
     
        Shift red 11 bits to the right, mask 5 bits.
        Shift green 5 bits to the right, mask 6 bits.
        Blue does not need a shift, just mask 5 bits.
     */
    uint8_t r5 = (color >> 11) & 0x1F;
    uint8_t g6 = (color >> 5) & 0x3F;
    uint8_t b5 = color & 0x1F;
    
    _r8 = (r5 << 3) | (r5 >> 2);
    _g8 = (g6 << 2) | (g6 >> 4);
    _b8 = (b5 << 3) | (b5 >> 2);
    
    return self;
}

-(id)initWithTrueColor:(uint32_t)color {
    self = [super init];
    
    _r8 = (color >> 24) & 0xFF;
    _g8 = (color >> 16) & 0xFF;
    _b8 = (color >> 8) & 0xFF;
    
    return self;
}

-(uint32_t)trueColor:(uint8_t)alpha {
    return (_r8 << 24) | (_g8 << 16) | (_b8 << 8) | alpha;
}

-(NSColor*)calibratedColor:(uint8_t)alpha gammaCorrection:(CGFloat)power {
    CGFloat red   = pow(_r8/255.0, power);
    CGFloat green = pow(_g8/255.0, power);
    CGFloat blue  = pow(_b8/255.0, power);
    CGFloat alph  = alpha/255.0f;
    
    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alph];
}

-(id)linearBlend:(HighColor*)otherColor {
    uint8_t r = (uint8_t) ((self.r8 + otherColor.r8)/2);
    uint8_t g = (uint8_t) ((self.g8 + otherColor.g8)/2);
    uint8_t b = (uint8_t) ((self.b8 + otherColor.b8)/2);
    uint32_t rgb = (r << 24) | (g << 16) | (b << 8);
    
    return [[HighColor alloc] initWithTrueColor:rgb];
}

-(id)linearInterpolation:(HighColor*)otherColor {
    uint8_t r = (uint8_t) ((self.r8*2 + otherColor.r8)/3);
    uint8_t g = (uint8_t) ((self.g8*2 + otherColor.g8)/3);
    uint8_t b = (uint8_t) ((self.b8*2 + otherColor.b8)/3);
    uint32_t rgb = (r << 24) | (g << 16) | (b << 8);
    
    return [[HighColor alloc] initWithTrueColor:rgb];
}

@end
