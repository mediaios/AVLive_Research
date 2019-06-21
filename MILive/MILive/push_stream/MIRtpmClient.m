//
//  MIRtpmClient.m
//  MILive
//
//  Created by mediaios on  2019/6/21.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIRtpmClient.h"
#define RTMP_HEAD_SIZE (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)

@implementation MIRtpmClient

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self->workQueue = dispatch_queue_create("rtmpSendQueue", NULL);
    }
    return self;
}


static MIRtpmClient* shareInstace = nil;
+ (instancetype)getInstance
{
    static dispatch_once_t instance;
    dispatch_once(&instance, ^{
        shareInstace = [[self alloc] init];
    });
    return shareInstace;
}

- (RTMP*)getCurrentRtmp
{
    return self->rtmp;
}

- (BOOL)startRtmpConnect:(NSString *)urlString
{
    self.rtmpUrl = urlString;
    if(self->rtmp)
    {
        [self stopRtmpConnect];
    }
    
    self->rtmp = RTMP_Alloc();
    RTMP_Init(self->rtmp);
    int err = RTMP_SetupURL(self->rtmp, (char*)[_rtmpUrl cStringUsingEncoding:NSASCIIStringEncoding]);
    
    if(err < 0)
    {
        NSLog(@"RTMP_SetupURL failed");
        RTMP_Free(self->rtmp);
        return false;
    }
    
    RTMP_EnableWrite(self->rtmp);
    
    err = RTMP_Connect(self->rtmp, NULL);
    
    if(err < 0)
    {
        NSLog(@"RTMP_Connect failed");
        RTMP_Free(self->rtmp);
        return false;
    }
    
    err = RTMP_ConnectStream(self->rtmp, 0);
    
    if(err < 0)
    {
        NSLog(@"RTMP_ConnectStream failed");
        RTMP_Close(self->rtmp);
        RTMP_Free(self->rtmp);
        exit(0);
        return false;
    }
    
    self->start_time = [[NSDate date] timeIntervalSince1970]*1000;
    
    return true;
}


- (BOOL)stopRtmpConnect
{
    if(self->rtmp != NULL)
    {
        RTMP_Close(self->rtmp);
        RTMP_Free(self->rtmp);
        return true;
    }
    return false;
}


@end
