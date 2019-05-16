//
//  MIAudioQueue.m
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/15.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIAudioQueue.h"
#import <AVFoundation/AVFoundation.h>


/** Audio recorder **/
#define kAudioQueueRecorderSampleRate               48000
#define kAudioQueueRecorderPCMFramesPerPacket       1
#define kAudioQueueRecorderPCMTotalPacket           512
#define kAudioQueueRecorderAudioBytesPerPacket       2

#define kAudioRecoderPCMMaxBuffSize                 2048



#define kNumberQueueBuffers 3



/*!
 @discussion
 AudioQueue 音频录制回调函数
 @param      inAQ
 回调函数的音频队列.
 @param      inBuffer
 是一个被音频队列填充新的音频数据的音频队列缓冲区，它包含了回调函数写入文件所需要的新数据.
 @param      inStartTime
 是缓冲区中的一采样的参考时间
 @param      inNumberPacketDescriptions
 参数中包描述符（packet descriptions）的数量，如果你正在录制一个VBR(可变比特率（variable bitrate））格式, 音频队列将会提供这个参数给你的回调函数，这个参数可以让你传递给AudioFileWritePackets函数. CBR (常量比特率（constant bitrate）) 格式不使用包描述符。对于CBR录制，音频队列会设置这个参数并且将inPacketDescs这个参数设置为NULL
 
 */
static void inputAudioQueueBufferHandler(void * __nullable               inUserData,
                               AudioQueueRef                   inAQ,
                               AudioQueueBufferRef             inBuffer,
                               const AudioTimeStamp *          inStartTime,
                               UInt32                          inNumberPacketDescriptions,
                               const AudioStreamPacketDescription * __nullable inPacketDescs)
{
    if (!inUserData) {
        NSLog(@"AppRecordAudio,%s,inUserData is null",__func__);
        return;
    }
    
    NSLog(@"%s, audio length: %d",__func__,inBuffer->mAudioDataByteSize);
    static int createCount = 0;
    static FILE *fp_pcm = NULL;
    if (createCount == 0) {
        NSString *paths = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *debugUrl = [paths stringByAppendingPathComponent:@"debug"] ;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager createDirectoryAtPath:debugUrl withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSString *audioFile = [paths stringByAppendingPathComponent:@"debug/queue_pcm_48k.pcm"] ;
        fp_pcm = fopen([audioFile UTF8String], "wb++");
    }
    createCount++;
    
    
    MIAudioQueue *miAQ = (__bridge MIAudioQueue *)inUserData;
    if (createCount <= 500) {
        void *bufferData = inBuffer->mAudioData;
        UInt32 buffersize = inBuffer->mAudioDataByteSize;
        fwrite((uint8_t *)bufferData, 1, buffersize, fp_pcm);
    }else{
        fclose(fp_pcm);
        NSLog(@"AudioQueue, close PCM file ");
        [miAQ stopRecorder];
    }
    
    if (miAQ.m_isRunning) {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
    
}



@interface MIAudioQueue()
{
    AudioStreamBasicDescription     dataFormat;
    AudioQueueRef                   mQueue;
    AudioQueueBufferRef             mBuffers[kNumberQueueBuffers];
}
@end

@implementation MIAudioQueue


- (void)startRecorder
{
    if (self.m_isRunning) {
        return;
    }
    
    [self settingAndStartAVAudioSession];
    [self setUpAudioQueueWithFormatID:kAudioFormatLinearPCM];
    
    
    OSStatus status = 0;
    //    int bufferByteSize = 0;
    UInt32 size = sizeof(dataFormat);
    
    status = AudioQueueNewInput(&dataFormat, inputAudioQueueBufferHandler, (__bridge void *)self, NULL, NULL, 0, &mQueue);
    if (status != noErr) {
        NSLog(@"AppRecordAudio,%s,AudioQueueNewInput failed status:%d ",__func__,(int)status);
    }
    
    status = AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription, &dataFormat, &size);
    if (status != noErr) {
        NSLog(@"AppRecordAudio,%s,kAudioQueueProperty_StreamDescription failed status:%d ",__func__,(int)status);
    }
    
    NSLog(@"AppRecordAudio,%s,pcm raw data buff number:%d, channel number:%u",__func__,kNumberQueueBuffers,
          dataFormat.mChannelsPerFrame);
    
    for (int i = 0 ; i < kNumberQueueBuffers; i++) {
        status = AudioQueueAllocateBuffer(mQueue, kAudioQueueRecorderPCMTotalPacket * kAudioQueueRecorderAudioBytesPerPacket * dataFormat.mChannelsPerFrame, &mBuffers[i]);
        NSLog(@"AppRecordAudio,%s,AudioQueueAllocateBuffer status:%d ",__func__,(int)status);
        status = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
        NSLog(@"AppRecordAudio,%s,AudioQueueEnqueueBuffer status:%d ",__func__,(int)status);
    }
    
    status = AudioQueueStart(mQueue, NULL);
    if (status != noErr) {
        NSLog(@"AppRecordAudio,%s,AudioQueueStart failed status:%d  ",__func__,(int)status);
    }
    self.m_isRunning = YES;
}

- (void)stopRecorder
{
    if (!self.m_isRunning) {
        return;
    }
    self.m_isRunning = NO;
    
    if (mQueue) {
        OSStatus stopRes = AudioQueueStop(mQueue, true);
        
        if (stopRes == noErr) {
            for (int i = 0; i < kNumberQueueBuffers; i++) {
                AudioQueueFreeBuffer(mQueue, mBuffers[i]);
            }
        }else{
            NSLog(@"AppRecordAudio,%s,stop AudioQueue failed.  ",__func__);
        }
        
        AudioQueueDispose(mQueue, true);
        mQueue = NULL;
    }
}

#pragma mark --about AudioQueue method
- (void)setUpAudioQueueWithFormatID:(UInt32)formatID
{
    // setup audio sample rate , channels number, and format ID
    memset(&dataFormat, 0, sizeof(dataFormat));
    
    UInt32 size = sizeof(dataFormat.mSampleRate);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &dataFormat.mSampleRate);
    dataFormat.mSampleRate = kAudioQueueRecorderSampleRate;
    
    size = sizeof(dataFormat.mChannelsPerFrame);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels, &size, &dataFormat.mChannelsPerFrame);
    
    dataFormat.mFormatID = formatID;
    dataFormat.mChannelsPerFrame = 1;
    
    if (formatID == kAudioFormatLinearPCM) {
        dataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        dataFormat.mBitsPerChannel = 16;
        dataFormat.mBytesPerPacket = dataFormat.mBytesPerFrame = (dataFormat.mBitsPerChannel / 8) * dataFormat.mChannelsPerFrame;
        dataFormat.mFramesPerPacket = kAudioQueueRecorderPCMFramesPerPacket; // AudioQueue collection pcm data , need to set as this
    }
}

#pragma mark --setting AVAudioSession
- (void)settingAndStartAVAudioSession
{
    NSError *error = nil;
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];  // if onlay record , setting AVAudioSessionCategoryRecord; if only play , setting AVAudioSessionCategoryPlayback
    if (!ret) {
        NSLog(@"AppRecordAudio,%s,setting AVAudioSession category failed",__func__);
        return;
    }
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret) {
        NSLog(@"AppRecordAudio,%s,start audio session failed",__func__);
        return;
    }
    
}



@end
