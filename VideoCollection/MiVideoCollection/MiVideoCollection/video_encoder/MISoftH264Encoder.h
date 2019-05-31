//
//  MISoftH264Encoder.h
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/30.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>


#ifdef __cplusplus
extern "C"
{
#endif
    
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/avstring.h"
#include "libavutil/imgutils.h"
#include "libavutil/error.h"
#include "libswscale/swscale.h"
#include <libavutil/dict.h>
#include <time.h>
#include <stdio.h>
#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_BEGIN

@interface MISoftH264Encoder : NSObject

+ (instancetype)getInstance;
- (void)setFileSavedPath:(NSString *)path;
- (int)setEncoderVideoWidth:(int)width height:(int)height bitrate:(int)bitrate;
- (void)encoderToH264:(CMSampleBufferRef)sampleBuffer;
- (void)freeH264Resource;

@end

NS_ASSUME_NONNULL_END
