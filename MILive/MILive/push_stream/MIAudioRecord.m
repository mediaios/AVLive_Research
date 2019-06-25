//
//  MIAudioQueueConvert.m
//  MILive
//
//  Created by mediaios on 2019/5/20.
//  Copyright © 2019年 iosmediadev@gmail.com. All rights reserved.
//

#import "MIAudioRecord.h"
#import "MIConst.h"


AudioStreamBasicDescription audioStreamDes;
AudioConverterRef miAACConvert;

static size_t  _pcmBufferSize;
static char* _pcmBuffer;

// AudioConverterRef Callback
OSStatus pcmEncodeCallback(AudioConverterRef              inAudioConverter,
                                             UInt32                         *ioNumberDataPackets,
                                             AudioBufferList                *ioData,
                                             AudioStreamPacketDescription   **outDataPacketDescription,
                                             void                           *inUserData) {
    MIAudioRecord *encoder = (__bridge MIAudioRecord *)(inUserData);
    
    UInt32 requestedPackets = *ioNumberDataPackets;
    size_t copiedSamples = [encoder copyPCMSamplesIntoBuffer:ioData];
    if (copiedSamples < requestedPackets) {
        //PCM 缓冲区还没满
        *ioNumberDataPackets = 0;
        return -1;
    }
    *ioNumberDataPackets = 1;
    
    return noErr;
}

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
static void recordAudioCallBack(void * __nullable               inUserData,
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
    _pcmBufferSize = 0;
    _pcmBuffer = NULL;
    _pcmBuffer = inBuffer->mAudioData;
    _pcmBufferSize = inBuffer->mAudioDataByteSize;
    
    MIAudioRecord *miAQ = (__bridge MIAudioRecord *)inUserData;
    [miAQ encodePCMToAAC:miAQ];
    if (miAQ.m_isRunning) {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
}

@interface MIAudioRecord()
{
    AudioQueueRef                   mQueue;
    AudioStreamBasicDescription inAudioStreamDes;

    AudioQueueBufferRef             mBuffers[kQueueBuffers];
}

@property (nonatomic) uint8_t *aacBuffer;
@property (nonatomic) NSUInteger aacBufferSize;

@property (nonatomic) BOOL sentAudioHead;
@property (nonatomic ,assign,readonly) char *asc;
@end

@implementation MIAudioRecord

- (void)setAudioSampleRate{
    NSInteger sampleRateIndex = 4;
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x3);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((/*self.numberOfChannels*/1 & 0xF) << 3);
}

- (void)setNumberOfChannels{
    //    NSInteger sampleRateIndex = [self sampleRateIndex:self.audioSampleRate];
    NSInteger sampleRateIndex = 4;
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x3);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((/*numberOfChannels*/1 & 0xF) << 3);
}

- (instancetype)init
{
    if (self = [super init]) {
        
        _aacBufferSize = 1024;
        _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
        memset(_aacBuffer, 0, _aacBufferSize);
    }
    return self;
}


- (void)createAudioSession
{
    /*** create audiosession ***/
    NSError *error = nil;
//    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:&error];  // if onlay record , setting AVAudioSessionCategoryRecord; if only play , setting AVAudioSessionCategoryPlayback
    
    BOOL ret =  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:nil];
    
    
    if (!ret) {
        NSLog(@"AppRecordAudio,%s,setting AVAudioSession category failed",__func__);
        return;
    }
    [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeVideoRecording error:&error];
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret) {
        NSLog(@"AppRecordAudio,%s,start audio session failed",__func__);
        return;
    }
    
    _asc = malloc(2);
    [self setAudioSampleRate];
    [self setNumberOfChannels];
}

- (void)settingInputAudioFormat
{
    /*** setup audio sample rate , channels number, and format ID ***/
    memset(&inAudioStreamDes, 0, sizeof(inAudioStreamDes));
    UInt32 size = sizeof(inAudioStreamDes.mSampleRate);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &inAudioStreamDes.mSampleRate);
    inAudioStreamDes.mSampleRate = 44100;
    size = sizeof(inAudioStreamDes.mChannelsPerFrame);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels, &size, &inAudioStreamDes.mChannelsPerFrame);
    inAudioStreamDes.mFormatID = kAudioFormatLinearPCM;
    inAudioStreamDes.mChannelsPerFrame = 1;
    inAudioStreamDes.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    inAudioStreamDes.mBitsPerChannel = 16;
    inAudioStreamDes.mBytesPerPacket = inAudioStreamDes.mBytesPerFrame = (inAudioStreamDes.mBitsPerChannel / 8) * inAudioStreamDes.mChannelsPerFrame;
    inAudioStreamDes.mFramesPerPacket = kAudioFramesPerPacket; // AudioQueue collection pcm data , need to set as this
}

- (void)settingRecordCallBackFunc
{
    /*** 设置录音回调函数 ***/
    OSStatus status = 0;
    //    int bufferByteSize = 0;
    UInt32 size = sizeof(inAudioStreamDes);
    status = AudioQueueNewInput(&inAudioStreamDes, recordAudioCallBack, (__bridge void *)self, NULL, NULL, 0, &mQueue);
    if (status != noErr) {
        NSLog(@"AppRecordAudio,%s,AudioQueueNewInput failed status:%d ",__func__,(int)status);
    }
    
    for (int i = 0 ; i < kQueueBuffers; i++) {
        status = AudioQueueAllocateBuffer(mQueue, kAudioPCMTotalPacket * kAudioBytesPerPacket * inAudioStreamDes.mChannelsPerFrame, &mBuffers[i]);
        status = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
    }
}

- (void)settingDestAudioStreamDescription
{
    audioStreamDes.mSampleRate = 44100;
    audioStreamDes.mFormatID = kAudioFormatMPEG4AAC;
    audioStreamDes.mBytesPerPacket = 0;
    audioStreamDes.mFramesPerPacket = 1024;
    audioStreamDes.mBytesPerFrame = 0;
    audioStreamDes.mChannelsPerFrame = 1;
    audioStreamDes.mBitsPerChannel = 0;
    audioStreamDes.mReserved = 0;
    AudioClassDescription *des = [self getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC
                                                       fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    OSStatus status = AudioConverterNewSpecific(&inAudioStreamDes, &audioStreamDes, 1, des, &miAACConvert);
    if (status != 0) {
        NSLog(@"create convert failed...\n");
    }
    
    UInt32 targetSize   = sizeof(audioStreamDes);
    UInt32 bitRate  =  64000;
    targetSize      = sizeof(bitRate);
    status          = AudioConverterSetProperty(miAACConvert,
                                                kAudioConverterEncodeBitRate,
                                                targetSize, &bitRate);
    if (status != noErr) {
        NSLog(@"set bitrate error...");
        return;
    }
}

/**
 *  获取编解码器
 *  @param type         编码格式
 *  @param manufacturer 软/硬编
 *  @return 指定编码器
 */
- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type
                                           fromManufacturer:(UInt32)manufacturer
{
    static AudioClassDescription desc;
    
    UInt32 encoderSpecifier = type;
    OSStatus st;
    
    UInt32 size;
    // 取得给定属性的信息
    st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,
                                    &size);
    if (st) {
        NSLog(@"error getting audio format propery info: %d", (int)(st));
        return nil;
    }
    
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    // 取得给定属性的数据
    st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (st) {
        NSLog(@"error getting audio format propery: %d", (int)(st));
        return nil;
    }
    
    for (unsigned int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) &&
            (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&desc, &(descriptions[i]), sizeof(desc));
            return &desc;
        }
    }
    
    return nil;
}

static int initTime = 0;
- (void)encodePCMToAAC:(MIAudioRecord *)convert
{
    if (initTime == 0) {
        initTime = 1;
        [self settingDestAudioStreamDescription];
    }
    OSStatus status;
    memset(_aacBuffer, 0, _aacBufferSize);
    
    AudioBufferList *bufferList             = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers              = 1;
    bufferList->mBuffers[0].mNumberChannels = audioStreamDes.mChannelsPerFrame;
    bufferList->mBuffers[0].mData           = _aacBuffer;
    bufferList->mBuffers[0].mDataByteSize   = (int)_aacBufferSize;
    
    AudioStreamPacketDescription outputPacketDescriptions;
    UInt32 inNumPackets = 1;
    status = AudioConverterFillComplexBuffer(miAACConvert,
                                             pcmEncodeCallback,
                                             (__bridge void *)(self),//inBuffer->mAudioData,
                                             &inNumPackets,
                                             bufferList,
                                             &outputPacketDescriptions);
    NSData *data = nil;
    if (status == noErr) {
        NSData *rawAAC = [NSData dataWithBytes:bufferList->mBuffers[0].mData length:bufferList->mBuffers[0].mDataByteSize];
        if (!self.sentAudioHead) {
            char exeData[2];
            exeData[0] = self.asc[0];
            exeData[1] = self.asc[1];
            NSData *headerData =[NSData dataWithBytes:exeData length:2];
            [self.delegate audioEncoder:self audioHeader:headerData];
            self.sentAudioHead =  YES;
        }else{
            data = rawAAC;
            [self.delegate audioEncoder:self audioData:data];
        }
    }
}

- (void)startRecorder
{
    [self createAudioSession];
    [self settingInputAudioFormat];
    [self settingRecordCallBackFunc];
    
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


/**
 *  填充PCM到缓冲区
 */
- (size_t) copyPCMSamplesIntoBuffer:(AudioBufferList*)ioData {
    size_t originalBufferSize = _pcmBufferSize;
    if (!originalBufferSize) {
        return 0;
    }
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mBuffers[0].mDataByteSize = (int)_pcmBufferSize;
    _pcmBuffer = NULL;
    _pcmBufferSize = 0;
    return originalBufferSize;
}
    

@end
