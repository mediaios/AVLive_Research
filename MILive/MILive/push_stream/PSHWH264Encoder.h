//
//  PSHWH264Encoder.h
//  MILive
//
//  Created by mediaios on 2019/6/25.
//  Copyright © 2019 ucloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class PSHWH264Encoder;
@protocol  PSHWH264EncoderDelegate<NSObject>

@optional

/**
 视频编码回调(当获取到sps,pps时触发)
 */
- (void)videoEncoder:(PSHWH264Encoder *)encoder sps:(NSData *)sps  pps:(NSData *)pps;

/**
 视频编码回调(当编码成功视频时触发)
 */
- (void)videoEncoder:(PSHWH264Encoder *)encoder videoData:(NSData *)vData  isKeyFrame:(BOOL)isKey;

@end


@interface PSHWH264Encoder : NSObject
{
    NSLock *m_lock;
    VTCompressionSessionRef compressionSession;
}
@property (nonatomic,weak) id<PSHWH264EncoderDelegate> delegate;
@property (assign, nonatomic) int width;
@property (assign, nonatomic) int height;
@property (assign, nonatomic) int fps;
@property (assign, nonatomic) int bitrate;//bps
@property (strong, nonatomic) NSData *sps;
@property (strong, nonatomic) NSData *pps;

+ (instancetype)getInstance;
- (void)settingEncoderParametersWithWidth:(int)width height:(int)height fps:(int)fps;
- (void)encoder:(CMSampleBufferRef)sampleBuffer;
@end

NS_ASSUME_NONNULL_END
