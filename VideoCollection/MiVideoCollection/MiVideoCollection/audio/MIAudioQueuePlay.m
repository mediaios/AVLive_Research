//
//  MIAudioQueuePlay.h
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/17.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIAudioQueuePlay.h"
#import <AVFoundation/AVFoundation.h>
#import "MIConst.h"

static void miAudioPlayCallBack(void *       inUserData,
                                AudioQueueRef           inAQ,
                                AudioQueueBufferRef     inBuffer)
{
    MIAudioQueuePlay *aqPlay = (__bridge MIAudioQueuePlay *)inUserData;
    [aqPlay readPCMAndPlay:inAQ buffer:inBuffer];
}

@interface MIAudioQueuePlay()
{
    AudioStreamBasicDescription     dataFormat;
    AudioQueueRef                   mQueue;
    AudioQueueBufferRef             mBuffers[kQueueBuffers];
    
    NSLock *synlock;
    Byte *pcmDataBuffer; // pcm的读文件数据区
    FILE *file ; // pcm源文件
}
@end

@implementation MIAudioQueuePlay

- (void)initPlayedFile
{
    NSString *paths = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *audioFile = [paths stringByAppendingPathComponent:@"debug/queue_pcm_48k.pcm"] ;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSLog(@"file exist = %d",[manager fileExistsAtPath:audioFile]);
    NSLog(@"file size = %lld",[[manager attributesOfItemAtPath:audioFile error:nil] fileSize]) ;
    file  = fopen([audioFile UTF8String], "r");
    if(file)
    {
        fseek(file, 0, SEEK_SET);
        pcmDataBuffer = malloc(1024);
    }
    else{
        NSLog(@"!!!!!!!!!!!!!!!!");
    }
    synlock = [[NSLock alloc] init];
}

- (void)createAudioSession
{
    /*** create audiosession ***/
    NSError *error = nil;
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];  // if onlay record , setting AVAudioSessionCategoryRecord; if only play , setting AVAudioSessionCategoryPlayback
    if (!ret) {
        NSLog(@"AppPlayAudio,%s,setting AVAudioSession category failed",__func__);
        return;
    }
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret) {
        NSLog(@"AppPlayAudio,%s,start audio session failed",__func__);
        return;
    }
}

- (void)settingAudioFormat
{
    /*** setup audio sample rate , channels number, and format ID ***/
    memset(&dataFormat, 0, sizeof(dataFormat));
    UInt32 size = sizeof(dataFormat.mSampleRate);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &dataFormat.mSampleRate);
    dataFormat.mSampleRate = kAudioSampleRate;
    size = sizeof(dataFormat.mChannelsPerFrame);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels, &size, &dataFormat.mChannelsPerFrame);
    dataFormat.mFormatID = kAudioFormatLinearPCM;
    dataFormat.mChannelsPerFrame = 1;
    dataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    dataFormat.mBitsPerChannel = 16;
    dataFormat.mBytesPerPacket = dataFormat.mBytesPerFrame = (dataFormat.mBitsPerChannel / 8) * dataFormat.mChannelsPerFrame;
    dataFormat.mFramesPerPacket = kAudioFramesPerPacket; // AudioQueue collection pcm data , need to set as this
}

- (void)settingCallBackFunc
{
    /*** 设置录音回调函数 ***/
    OSStatus status = 0;
    //    int bufferByteSize = 0;
    UInt32 size = sizeof(dataFormat);
    
    /*** 设置播放回调函数 ***/
    status = AudioQueueNewOutput(&dataFormat,
                                 miAudioPlayCallBack,
                                 (__bridge void *)self,
                                 NULL,
                                 NULL,
                                 0,
                                 &mQueue);
    if (status != noErr) {
        NSLog(@"AppRecordAudio,%s, AudioQueueNewOutput failed status:%d",__func__,(int)status);
    }
    
    for (int i = 0 ; i < kQueueBuffers; i++) {
        status = AudioQueueAllocateBuffer(mQueue, kAudioPCMTotalPacket * kAudioBytesPerPacket * dataFormat.mChannelsPerFrame, &mBuffers[i]);
        status = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
    }
    
    
    //    for (int i = 0; i < kQueueBuffers; i++) {
    //        int result =  AudioQueueAllocateBuffer(mQueue, kAudioPCMTotalPacket * kAudioBytesPerPacket * dataFormat.mChannelsPerFrame, &mBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
    //        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d",i,result);
    //    }
}


- (void)startPlay
{
    [self initPlayedFile];
    [self createAudioSession];
    [self settingAudioFormat];
    [self settingCallBackFunc];
    
    AudioQueueStart(mQueue, NULL);
    for (int i = 0; i < kQueueBuffers; i++) {
        [self readPCMAndPlay:mQueue buffer:mBuffers[i]];
    }
}

-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB
{
    [synlock lock];
    int readLength = fread(pcmDataBuffer, 1, 1024, file);//读取文件
    NSLog(@"read raw data size = %d",readLength);
    outQB->mAudioDataByteSize = readLength;
    Byte *audiodata = (Byte *)outQB->mAudioData;
    for(int i=0;i<readLength;i++)
    {
        audiodata[i] = pcmDataBuffer[i];
    }
    /*
     将创建的buffer区添加到audioqueue里播放
     AudioQueueBufferRef用来缓存待播放的数据区，AudioQueueBufferRef有两个比较重要的参数，AudioQueueBufferRef->mAudioDataByteSize用来指示数据区大小，AudioQueueBufferRef->mAudioData用来保存数据区
     */
    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
    [synlock unlock];
}
@end
