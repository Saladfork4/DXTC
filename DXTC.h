//
//  DXTC.h
//  DXTC
//
//  Created by Saladfork on 10/16/15.
//  Copyright © 2015 Saladfork. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HighColor.h"

/* DXTC Format List */
#define DXTC_1    1
#define DXTC_1A   2
#define DXTC_3    3
#define DXTC_5    4

/* OS X specific value */
#define DXTC_GAMMA_CORRECTION   1.2f

typedef struct _DXTColorBlock {
    uint8_t colorLow0;
    uint8_t colorHigh0;
    uint8_t colorLow1;
    uint8_t colorHigh1;
    uint8_t codes[4];
} DXTColorBlock;

typedef struct _DXT3AlphaBlock {
    uint16_t alpha[4];
} DXT3AlphaBlock;

typedef struct _DXT5AlphaBlock {
    uint8_t alpha0;
    uint8_t alpha1;
    uint8_t codes[6];
} DXT5AlphaBlock;

@interface DXTC : NSObject

/**
 *  Decompresses the DXTC data and stores it in a bitmap.
 *  The source data should not include any header information.
 *  It should be just one mipmap.
 *
 *  - parameter: source     Source buffer with image data
 *  - parameter: width      Width of the image in pixels
 *  - parameter: height     Height of the image in pixels
 *  - parameter: format     See formats in DXTC.h
 *
 *  - returns: Bitmap with the image data
 */
+(nullable NSBitmapImageRep*)decompress:(nonnull NSData*)source
                        width:(uint32_t)w
                       height:(uint32_t)h
                       format:(unsigned int)format;

@end
