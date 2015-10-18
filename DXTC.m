//
//  DXTC.m
//  DXTC
//
//  Created by Saladfork on 10/16/15.
//  Copyright © 2015 Saladfork. All rights reserved.
//

#import "DXTC.h"

@implementation DXTC

+(NSArray*)decompressColorBlock:(DXTColorBlock)block DXT1:(BOOL)DXT1 {
    NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:16];
    
    HighColor *colors[4];
    uint16_t c0 = (block.colorHigh0 << 8) | block.colorLow0;
    uint16_t c1 = (block.colorHigh1 << 8) | block.colorLow1;
    
    colors[0] = [[HighColor alloc] initWithColor:c0];
    colors[1] = [[HighColor alloc] initWithColor:c1];
    
    if (!DXT1 || c0 > c1) {
        colors[2] = [colors[0] linearInterpolation:colors[1]];
        colors[3] = [colors[1] linearInterpolation:colors[0]];
    } else {
        colors[2] = [colors[0] linearBlend:colors[1]];
        colors[3] = [[HighColor alloc] initWithColor:0];
    }
    
    for (int k = 0; k < 4; k++) {
        for (int j = 0; j < 4; j++) {
            int idx = (block.codes[j] >> (k*2)) & 0x3;
            NSColor *color = [colors[idx] calibratedColor:255 gammaCorrection:DXTC_GAMMA_CORRECTION];
            [results addObject:color];
        }
    }
    
    return results;
}

/**
    :: DXT1 ::
 
    Data is processed in 64-bit (8-byte) blocks. Each block conforms to
    the data organization specified in DXT1Block (see DXTC.h).
 
    c0 and c1 are stored within the block. The low bytes are stored before
    the high bytes, so we need to shift it up.
 
    c2 and c3 are calculated based on the relationship between c0 and c1.
 
    The block contains c0 and c1, followed by a look-up table to map any
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
    
    DXTColorBlock block;
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
            
            start -> 0000 0011
                     0000 1100
                     0011 0000
            end   -> 1100 0000
         
            We apply the mask to each of the 4 code-tables in the data block.
         */
        int mask = 0x3;
        for (int k = 0; k < 4; k++) {
            for (int j = 0; j < 4; j++) {
                int index = (block.codes[j] & mask) >> (k*2);
                uint8_t a = (alpha && c0 <= c1) ? 0 : 255;
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

/**
    :: DXT3 ::
 
    DXT3 is essentially DXT1 with alpha and some subtle differences:
 
    (1) Data is processed in 128-bit chunks. The first 64-bits are alpha data.
        Each 4-bit entry corresponds to one pixel's alpha value.
    (2) The second 64-bits are handled exactly the same way as DXT1, except that
        you'll always use the linear interpolation rule (to form c2 and c3) rather
        choosing between the two. i.e. c3 does NOT become a reserved color.
 */
+(NSBitmapImageRep*)decompressDXT3:(NSData*)source bitmap:(NSBitmapImageRep*)bitmap
                             width:(uint32_t)width height:(uint32_t)height {
    int x = 0; int y = 0;
    int end = (int)[source length];
    
    DXTColorBlock  block;
    DXT3AlphaBlock alpha;
    HighColor *colors[4];
    
    for (int offset = 0; offset < end; offset += 16) {
        [source getBytes:&alpha range:NSMakeRange(offset, 8)];
        [source getBytes:&block range:NSMakeRange(offset + 8, 8)];
        
        uint16_t c0 = ((uint16_t)block.colorHigh0 << 8) + block.colorLow0;
        uint16_t c1 = ((uint16_t)block.colorHigh1 << 8) + block.colorLow1;
        
        colors[0] = [[HighColor alloc] initWithColor:c0];
        colors[1] = [[HighColor alloc] initWithColor:c1];
        colors[2] = [colors[0] linearInterpolation:colors[1]];
        colors[3] = [colors[1] linearInterpolation:colors[0]];
        
        int mask  = 0x3;
        int amask = 0xF;
        for (int k = 0; k < 4; k++) {
            for (int j = 0; j < 4; j++) {
                uint32_t a = (alpha.alpha[j] & amask) >> (k*4);
                a = (uint32_t) (255.0f/15 * a);
                int index  = (block.codes[j] & mask) >> (k*2);
                NSColor *ns = [colors[index] calibratedColor:a gammaCorrection:DXTC_GAMMA_CORRECTION];
                [bitmap setColor:ns atX:(x + k) y:(y + j)];
            }
            mask = mask << 2;
            amask = amask << 4;
        }
        
        x += 4;
        if (x >= width) {
            x = 0;
            y += 4;
        }
    }
    
    return bitmap;
}

+(NSBitmapImageRep*)decompressDXT5:(NSData*)source bitmap:(NSBitmapImageRep*)bitmap
                             width:(uint32_t)width height:(uint32_t)height {
    int x = 0; int y = 0;
    int end = (int)[source length];
    
    DXTColorBlock  block;
    uint64_t  alphaBlock;
    HighColor *colors[4];
    uint32_t alphas[8];
    
    DXT5AlphaBlock ab;
    
    for (int offset = 0; offset < end; offset += 16) {
        [source getBytes:&alphaBlock range:NSMakeRange(offset, 8)];
        [source getBytes:&ab range:NSMakeRange(offset, 8)];
        [source getBytes:&block range:NSMakeRange(offset + 8, 8)];
        
        uint16_t c0 = ((uint16_t)block.colorHigh0 << 8) + block.colorLow0;
        uint16_t c1 = ((uint16_t)block.colorHigh1 << 8) + block.colorLow1;
        
        colors[0] = [[HighColor alloc] initWithColor:c0];
        colors[1] = [[HighColor alloc] initWithColor:c1];
        colors[2] = [colors[0] linearInterpolation:colors[1]];
        colors[3] = [colors[1] linearInterpolation:colors[0]];
        
        uint8_t pixelAlpha[16];
        alphas[0] = ab.alpha0;
        alphas[1] = ab.alpha1;
        
        
        if (alphas[0] > alphas[1]) {
            for (int j = 1; j < 7; j++) {
                int sum = (7 - j)*alphas[0] + j*alphas[1];
                alphas[j + 1] = sum/7;
            }
        } else {
            for (int j = 1; j < 5; j++) {
                int sum = (5 - j)*alphas[0] + j*alphas[1];
                alphas[j + 1] = sum/5;
            }
            alphas[6] = 0;
            alphas[7] = 255;
        }
        
        int value1 = ab.codes[0] | (ab.codes[1] << 8) | (ab.codes[2] << 16);
        int value2 = ab.codes[3] | (ab.codes[4] << 8) | (ab.codes[5] << 16);
        int alphaIndices[16];
        
        for (int i = 0; i < 8; i++) {
            alphaIndices[i] = (value1 >> 3*i) & 0x7;
            alphaIndices[i + 8] = (value2 >> 3*i) & 0x7;
        }
        
        for (int i = 0; i < 16; i++) {
            pixelAlpha[i] = alphas[alphaIndices[i]];
        }
        
        int mask  = 0x3;
        for (int k = 0; k < 4; k++) {
            for (int j = 0; j < 4; j++) {
                uint32_t a = pixelAlpha[j*4 + k];
                int index  = (block.codes[j] & mask) >> (k*2);
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
