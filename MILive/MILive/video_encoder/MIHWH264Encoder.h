//
//  MIHWH264Encoder.h
//  MILive
//
//  Created by mediaios on 2019/5/30.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

typedef enum{
    H264Data_NALU_TYPE_IDR = 0,
    H264Data_NALU_TYPE_NOIDR
}H264Data_NALU_TYPE;

@protocol MIHWH264EncoderDelegate<NSObject>
- (void)acceptEncoderData:(uint8_t *)data length:(int)len naluType:(H264Data_NALU_TYPE)naluType;
@end


NS_ASSUME_NONNULL_BEGIN

@interface MIHWH264Encoder : NSObject
{
    NSLock *m_lock;
    VTCompressionSessionRef compressionSession;
}
@property (nonatomic,weak) id<MIHWH264EncoderDelegate> delegate;
@property (assign, nonatomic) int width;
@property (assign, nonatomic) int height;
@property (assign, nonatomic) int fps;
@property (assign, nonatomic) int bitrate;//bps

+ (instancetype)getInstance;
- (void)settingEncoderParametersWithWidth:(int)width height:(int)height fps:(int)fps;
- (void)encoder:(CMSampleBufferRef)sampleBuffer;


@end

NS_ASSUME_NONNULL_END
