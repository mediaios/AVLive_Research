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
    dispatch_queue_t workQueue;//异步Queue
}

@property (nonatomic,copy) NSString* rtmpUrl;//rtmp服务器流地址

- (RTMP*)getCurrentRtmp;

/**
 *  获取单例
 *
 *  @return 单例
 */
+ (instancetype)getInstance;


- (BOOL)startRtmpConnect:(NSString *)urlString;
@end

NS_ASSUME_NONNULL_END
