//
//  DXTC.m
//  DXTC
//
//  Created by Saladfork on 10/16/15.
//  Copyright © 2015 Saladfork. All rights reserved.
//

#import "DXTC.h"

@implementation DXTC

/**
    Data is processed in 64-bit (8-byte) packs. Each pack conforms to
    the data organization specified in DXT1Block (see DXTC.h).
 
    c0 and c1 are stored within the pack. The low bytes are stored before
    the high bytes, so we need to shift it up.
 
    c2 and c3 are calculated based on the relationship between c0 and c1.
 
    The pack contains c0 and c1, followed by a look-up table to map any
    of the colors {c0, c1, c2, c3} to the corresponding 4x4 pixel block
    in the image. Each look-up item is 2-bits, i.e. 0 means to use c0 for
    that pixel, c1 means to use c1, etc.
 
    Alpha is not relevant to DXT1 except in the case of DXT1A. If it is
    DXT1A, then the c3 value should be 0 (transparent black) when c1 >= c0.
    Otherwise, c3 should have an alpha of 255 (but still be 0 for R/G/B).
 
    https://www.opengl.org/wiki/S3_Texture_Compression
    https://en.wikipedia.org/wiki/S3_Texture_Compression
    https://msdn.microsoft.com/en-us/library/windows/desktop/bb694531(v=vs.85).aspx#BC1
 */
+(NSBitmapImageRep*)decompressDXT1:(NSData*)source bitmap:(NSBitmapImageRep*)bitmap
                             width:(uint32_t)width height:(uint32_t)height alpha:(BOOL)alpha {
    
    int x = 0; int y = 0;
    int end = (int)[source length];
    
    DXT1Block block;
    HighColor *colors[4];
    
    for (int offset = 0; offset < end; offset += 8) {
        [source getBytes:&block range:NSMakeRange(offset, 8)];
        
        uint16_t c0 = ((uint16_t)block.colorHigh0 << 8) + block.colorLow0;
        uint16_t c1 = ((uint16_t)block.colorHigh1 << 8) + block.colorLow1;
        
        colors[0] = [[HighColor alloc] initWithColor:c0];
        colors[1] = [[HighColor alloc] initWithColor:c1];
        
        if (c0 > c1) {
            colors[2] = [colors[0] linearInterpolation:colors[1]];
            colors[3] = [colors[1] linearInterpolation:colors[0]];
        } else {
            colors[2] = [colors[0] linearBlend:colors[1]];
            colors[3] = [[HighColor alloc] initWithColor:0];
        }
        
        /*
            To extract indices from the look-up table, we need a mask.
            
            start -> 0000 0000 0000 0011
                     0000 0000 0000 1100
                     0000 0000 0011 0000
            end   -> 0000 0000 1100 0000
         
            We apply the mask to each of the 4 code-tables in the data block.
         */
        int mask = 0x3;
        for (int k = 0; k < 4; k++) {
            for (int j = 0; j < 4; j++) {
                int index = (block.codes[j] & mask) >> (k*2);
                uint8_t a = (alpha && [colors[index] color] == 0) ? 0 : 255;
                NSColor *ns = [colors[index] calibratedColor:a gammaCorrection:DXTC_GAMMA_CORRECTION];
                [bitmap setColor:ns atX:(x + k) y:(y + j)];
            }
            mask = mask << 2;
        }
        
        x += 4;
        if (x >= width) {
            x = 0;
            y += 4;
        }
    }
    
    return bitmap;
}

+(NSBitmapImageRep*)decompressDXT3:(NSData*)source bitmap:(NSBitmapImageRep*)bitmap
                             width:(uint32_t)width height:(uint32_t)height {
    return nil;
}

+(NSBitmapImageRep*)decompressDXT5:(NSData*)source bitmap:(NSBitmapImageRep*)bitmap
                             width:(uint32_t)width height:(uint32_t)height {
    return nil;
}

+(NSBitmapImageRep*)decompress:(NSData*)source
                         width:(uint32_t)w height:(uint32_t)h format:(unsigned int)fmt {
    
    /* TODO: Support dimensions that are not multiples of 4 */
    if (w % 4 != 0 || h % 4 != 0) {
        NSLog(@"Dimensions not supported.");
        return nil;
    }
    
    NSBitmapImageRep *bitmap =
    [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                            pixelsWide:w
                                            pixelsHigh:h
                                         bitsPerSample:8
                                       samplesPerPixel:4
                                              hasAlpha:YES
                                              isPlanar:NO
                                        colorSpaceName:NSCalibratedRGBColorSpace
                                          bitmapFormat:NS32BitLittleEndianBitmapFormat | NSAlphaNonpremultipliedBitmapFormat
                                           bytesPerRow:0
                                          bitsPerPixel:32];
    
    /* Determine which decompression algorithm to use based on the hint. */
    switch (fmt) {
        case DXTC_1:
            return [DXTC decompressDXT1:source bitmap:bitmap width:w height:h alpha:NO];
        case DXTC_1A:
            return [DXTC decompressDXT1:source bitmap:bitmap width:w height:h alpha:YES];
        case DXTC_3:
            return [DXTC decompressDXT3:source bitmap:bitmap width:w height:h];
        case DXTC_5:
            return [DXTC decompressDXT5:source bitmap:bitmap width:w height:h];
        default:
            break;
    }
    
    return nil;
}

@end
