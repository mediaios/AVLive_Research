//
//  MIRtpmClient.h
//  MILive
//
//  Created by mediaios on  2019/6/21.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <librtmp/rtmp.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIRtpmClient : NSObject
{
    RTMP* rtmp;
    double start_time;
}

- (RTMP*)getCurrentRtmp;

+ (instancetype)getInstance;
- (BOOL)startRtmpConnect:(NSString *)urlString;


/**
 发送视频sps，pps
 */
- (void)sendVideoSps:(NSData *)spsData pps:(NSData *)ppsData;

/**
 发送视频帧数据
 */
- (void)sendVideoData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame;

/**
 发送音频头信息
 */
- (void)sendAudioHeader:(NSData *)data;

/**
 发送音频数据
 */
- (void)sendAudioData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
