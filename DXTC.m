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
    :: DXT Color Block ::
 
    DXT1/3/5 all feature 64-bit color block chunks. The parsing is mostly
    the same between the formats, with some subtle differences for DXT1.
 
    The first 32-bits store two colors in High-Color 5:6:5 RGB format.
    The low-byte is stored before the high-byte, so you must do some
    shifting to get the 16-bit colors c0 and c1.
 
    DXT1: If c0 > c1, then interpolate between the two colors to form
          additional colors c2 and c3.
 
          If c0 <= c1, then c2 is the linear blend of c0 and c1, and
          c3 is set to black. If the format specifies an alpha, then
          c3 should be transparent black (all zeroes).
 
    DXT3 and DXT5: Always interpolate c0 and c1 to form c2 and c3.
 
    The last 32-bits store sixteen 2-bit indices => one for each pixel.
    For example, if the index for a pixel is '3', then that pixel
    should use the color stored in c3.
 */
+(NSArray*)decompressColorBlock:(DXTColorBlock)block DXT1:(BOOL)DXT1 DXT1A:(BOOL)DXT1A {
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
    
    for (int x = 0; x < 4; x++) {
        for (int y = 0; y < 4; y++) {
            int idx = (block.codes[x] >> y*2) & 0x3;
            int alpha = (DXT1A && idx == 3 && c0 <= c1) ? 0 : 255;
            NSColor *color = [colors[idx] calibratedColor:alpha gammaCorrection:DXTC_GAMMA_CORRECTION];
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
    DXTColorBlock block;
    int x = 0; int y = 0;
    
    for (int offset = 0; offset < [source length]; offset += 8) {
        [source getBytes:&block range:NSMakeRange(offset, 8)];
        
        /* Load and set pixel colors */
        NSArray *colors = [DXTC decompressColorBlock:block DXT1:YES DXT1A:alpha];
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                [bitmap setColor:colors[i*4 + j] atX:x + j y:y + i];
            }
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
 
    (1) Data is processed in 128-bit chunks. The first 64-bits is alpha data.
        Each 4-bit entry corresponds to one pixel's alpha value.
    (2) The second 64-bits are handled exactly the same way as DXT1, except that
        you'll always use the linear interpolation rule (to form c2 and c3) rather
        choosing between the two. i.e. c3 does NOT become a reserved color.
 */
+(NSBitmapImageRep*)decompressDXT3:(NSData*)source bitmap:(NSBitmapImageRep*)bitmap
                             width:(uint32_t)width height:(uint32_t)height {
    DXTColorBlock  block;
    DXT3AlphaBlock alphaBlock;
    int x = 0; int y = 0;
    
    for (int offset = 0; offset < [source length]; offset += 16) {
        [source getBytes:&alphaBlock range:NSMakeRange(offset, 8)];
        [source getBytes:&block range:NSMakeRange(offset + 8, 8)];
        
        /* Load and set pixel colors */
        NSArray *colors = [DXTC decompressColorBlock:block DXT1:NO DXT1A:NO];
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                uint32_t a = (alphaBlock.alpha[i] >> (j*4)) & 0xF;
                a = (a << 4) | (a);
                NSColor *color = [(NSColor*)colors[i*4 + j] colorWithAlphaComponent:a/255.0];
                [bitmap setColor:color atX:x + j y:y + i];
            }
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
    :: DXT5 ::
 
    DXT5 is similar to DXT3 in that it contains a 64-bit alpha chunk before each
    color chunk, but its alpha chunk is encoded with a look-up table similar to
    the method described in DXT1.
 
    The alpha chunk starts off with two 8-bit alpha colors a0 and a1.
    You can compute 5 other alpha colors using the method described here:
    https://www.opengl.org/wiki/S3_Texture_Compression#DXT5_Format
 
    The next 48-bits feature 3-bit indices that assign a particular alpha
    value to that pixel. For example, an index of 7 would indicate a7.
 
    48-bits and 3-bits are rather awkward to parse. My DXT5AlphaBlock grabs
    it as six 8-bit unsigned integers. The first three 8-bit integers are
    packed into one integer (32-bit) and the second three are packed into another.
    This allows you to loop and mask really easily. You could alternatively pack 
    them into a 64-bit integer. Either is fine.
    
    The 3 least-significant-bits of the first byte (8-bit) corresponds to the
    first pixel (0, 0) => upper-left corner pixel.
 */
+(NSBitmapImageRep*)decompressDXT5:(NSData*)source bitmap:(NSBitmapImageRep*)bitmap
                             width:(uint32_t)width height:(uint32_t)height {
    DXTColorBlock  block;
    DXT5AlphaBlock alphaBlock;
    int x = 0; int y = 0;
    
    int pixelAlpha[16];
    int alphas[8];
    
    for (int offset = 0; offset < [source length]; offset += 16) {
        [source getBytes:&alphaBlock range:NSMakeRange(offset, 8)];
        [source getBytes:&block range:NSMakeRange(offset + 8, 8)];
        
        alphas[0] = alphaBlock.alpha0;
        alphas[1] = alphaBlock.alpha1;
        
        /* Determine alpha computation method */
        if (alphas[0] > alphas[1]) {
            for (int i = 0; i < 6; i++)
                alphas[i + 2] = ((6 - i)*alphas[0] + (i + 1)*alphas[1])/7;
        } else {
            for (int i = 0; i < 4; i++)
                alphas[i + 2] = ((4 - i)*alphas[0] + (i + 1)*alphas[1])/5;
            alphas[6] = 0;
            alphas[7] = 255;
        }
        
        /* Pack the 8-bit codes into 24-bits */
        int alphaPack0 = alphaBlock.codes[0] | (alphaBlock.codes[1] << 8) | (alphaBlock.codes[2] << 16);
        int alphaPack1 = alphaBlock.codes[3] | (alphaBlock.codes[4] << 8) | (alphaBlock.codes[5] << 16);
        
        /* Extract 3-bits at a time */
        for (int i = 0; i < 8; i++) {
            int index0 = (alphaPack0 >> 3*i) & 0x7;
            int index1 = (alphaPack1 >> 3*i) & 0x7;
            pixelAlpha[i] = alphas[index0];
            pixelAlpha[i + 8] = alphas[index1];
        }
        
        /* Load and set pixel colors */
        NSArray *colors = [DXTC decompressColorBlock:block DXT1:NO DXT1A:NO];
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                uint32_t a = pixelAlpha[i*4 + j];
                NSColor *color = [(NSColor*)colors[i*4 + j] colorWithAlphaComponent:a/255.0];
                [bitmap setColor:color atX:x + j y:y + i];
            }
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
    Chooses which decompression method to use and passes along 
    bitmap data-planes to fill. The data passed should not contain
    a header (it should just be the raw image chunk).
 */
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
