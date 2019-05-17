//
//  MIAudioQueue.m
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/15.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIAudioQueue.h"
#import <AVFoundation/AVFoundation.h>


#define kAudioSampleRate            48000
#define kAudioFramesPerPacket       1
#define kAudioPCMTotalPacket        512
#define kAudioBytesPerPacket        2
#define kQueueBuffers 3  // 输出音频队列缓冲个数


#define EVERY_READ_LENGTH 1000 //每次从文件读取的长度
#define MIN_SIZE_PER_FRAME 2000 // 每帧最小数据长度

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
        
        NSString *audioFile = [paths stringByAppendingPathComponent:@"debug/queue_record_pcm_48k.pcm"] ;
        fp_pcm = fopen([audioFile UTF8String], "wb++");
    }
    createCount++;
    
    MIAudioQueue *miAQ = (__bridge MIAudioQueue *)inUserData;
    if (createCount <= 200) {
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


static void miAudioPlayCallBack(void * __nullable       inUserData,
                                 AudioQueueRef           inAQ,
                                 AudioQueueBufferRef     inBuffer)
{
    
}

@interface MIAudioQueue()
{
    AudioStreamBasicDescription     dataFormat;
    AudioQueueRef                   mQueue;
    AudioQueueBufferRef             mBuffers[kQueueBuffers];
}
@end

@implementation MIAudioQueue


- (void)createAudioSession
{
    /*** create audiosession ***/
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
    status = AudioQueueNewInput(&dataFormat, inputAudioQueueBufferHandler, (__bridge void *)self, NULL, NULL, 0, &mQueue);
    if (status != noErr) {
        NSLog(@"AppRecordAudio,%s,AudioQueueNewInput failed status:%d ",__func__,(int)status);
    }
    
//    /*** 设置播放回调函数 ***/
//    status = AudioQueueNewOutput(&dataFormat,
//                                 miAudioPlayCallBack,
//                                 (__bridge void *)self,
//                                 NULL,
//                                 NULL,
//                                 0,
//                                 &mQueue);
//    if (status != noErr) {
//        NSLog(@"AppRecordAudio,%s, AudioQueueNewOutput failed status:%d",__func__,(int)status);
//    }
    
    for (int i = 0 ; i < kQueueBuffers; i++) {
        status = AudioQueueAllocateBuffer(mQueue, kAudioPCMTotalPacket * kAudioBytesPerPacket * dataFormat.mChannelsPerFrame, &mBuffers[i]);
        status = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
    }
    
   
//    for (int i = 0; i < kQueueBuffers; i++) {
//        int result =  AudioQueueAllocateBuffer(mQueue, kAudioPCMTotalPacket * kAudioBytesPerPacket * dataFormat.mChannelsPerFrame, &mBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
//        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d",i,result);
//    }
}

- (void)startRecorder
{
    [self createAudioSession];
    [self settingAudioFormat];
    [self settingCallBackFunc];
    
    if (self.m_isRunning) {
        return;
    }

    /*** start audioQueue ***/
    OSStatus status = AudioQueueStart(mQueue, NULL);
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
            for (int i = 0; i < kQueueBuffers; i++) {
                AudioQueueFreeBuffer(mQueue, mBuffers[i]);
            }
        }else{
            NSLog(@"AppRecordAudio,%s,stop AudioQueue failed.  ",__func__);
        }
        
        AudioQueueDispose(mQueue, true);
        mQueue = NULL;
    }
}


- (void)startPlay
{
    
}

static FILE *fid ;
- (void)openPCMFile
{
    NSString *paths = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *audioFile = [paths stringByAppendingPathComponent:@"debug/queue_pcm_48k.pcm"] ;

    fid = fopen([audioFile UTF8String], "r");
    if (fid == NULL) {
        NSLog(@"读取文件失败");
    }
}

-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB
{
    char *buff[1024];
    int len = 0;
    while (len = fread(buff, sizeof(char), 1024, fid) != 0) {
        
    }
    
    
    uint8_t *buffer = malloc(sizeof(kAudioPCMTotalPacket * kAudioBytesPerPacket * dataFormat.mChannelsPerFrame));
    memset(buffer, 0, sizeof(buffer));
    int readLength = 1024;//读取文件
    NSLog(@"read raw data size = %d",readLength);
    outQB->mAudioDataByteSize = readLength;
    Byte *audiodata = (Byte *)outQB->mAudioData;
    for(int i=0;i<readLength;i++)
    {
        audiodata[i] = buffer[i];
    }
    /*
     将创建的buffer区添加到audioqueue里播放
     AudioQueueBufferRef用来缓存待播放的数据区，AudioQueueBufferRef有两个比较重要的参数，AudioQueueBufferRef->mAudioDataByteSize用来指示数据区大小，AudioQueueBufferRef->mAudioData用来保存数据区
     */
    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
    
//    uint8_t *buffer = malloc(sizeof(kAudioPCMTotalPacket * kAudioBytesPerPacket * dataFormat.mChannelsPerFrame));
//    memset(buffer, 0, sizeof(buffer));
//    fread(buffer, sizeof(buffer), 1, fid);
//    memcpy(outQB->mAudioData, buffer, <#size_t __n#>)
//
//
//
////    [synlock lock];
//    size_t readLength = [inputSteam read:pcmDataBuffer maxLength:EVERY_READ_LENGTH];
//    NSLog(@"read raw data size = %zi",readLength);
//    if (readLength == 0) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            NSLog(@"文件读取完成");
//        });
//        return ;
//    }
//    outQB->mAudioDataByteSize = (UInt32)readLength;
//    memcpy((Byte *)outQB->mAudioData, pcmDataBuffer, readLength);
//    /*
//     将创建的buffer区添加到audioqueue里播放
//     AudioQueueBufferRef用来缓存待播放的数据区，AudioQueueBufferRef有两个比较重要的参数，AudioQueueBufferRef->mAudioDataByteSize用来指示数据区大小，AudioQueueBufferRef->mAudioData用来保存数据区
//     */
//    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
////    [synlock unlock];
}



@end
