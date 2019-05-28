//
//  MIAudioQueueConvert.m
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/20.
//  Copyright © 2019年 iosmediadev@gmail.com. All rights reserved.
//

#import "MIAudioQueueConvert.h"
#import "MIConst.h"

AudioStreamBasicDescription outAudioStreamDes;
AudioConverterRef miAudioConvert;

static size_t  _pcmBufferSize;
static char* _pcmBuffer;

// AudioConverterRef Callback
OSStatus pcmEncodeConverterInputCallback(AudioConverterRef              inAudioConverter,
                                             UInt32                         *ioNumberDataPackets,
                                             AudioBufferList                *ioData,
                                             AudioStreamPacketDescription   **outDataPacketDescription,
                                             void                           *inUserData) {
    MIAudioQueueConvert *encoder = (__bridge MIAudioQueueConvert *)(inUserData);
    
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
    
    MIAudioQueueConvert *miAQ = (__bridge MIAudioQueueConvert *)inUserData;
    [miAQ encodePCMToAAC:miAQ];
    if (miAQ.m_isRunning) {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
}

@interface MIAudioQueueConvert()
{
    AudioQueueRef                   mQueue;
    AudioStreamBasicDescription inAudioStreamDes;

    AudioQueueBufferRef             mBuffers[kQueueBuffers];
}

@property (nonatomic) uint8_t *aacBuffer;
@property (nonatomic) NSUInteger aacBufferSize;
@end

@implementation MIAudioQueueConvert


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
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:&error];  // if onlay record , setting AVAudioSessionCategoryRecord; if only play , setting AVAudioSessionCategoryPlayback
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

- (void)settingInputAudioFormat
{
    /*** setup audio sample rate , channels number, and format ID ***/
    memset(&inAudioStreamDes, 0, sizeof(inAudioStreamDes));
    UInt32 size = sizeof(inAudioStreamDes.mSampleRate);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &inAudioStreamDes.mSampleRate);
    inAudioStreamDes.mSampleRate = kAudioSampleRate;
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
    outAudioStreamDes.mSampleRate = kAudioSampleRate;
    outAudioStreamDes.mFormatID = kAudioFormatMPEG4AAC;
    outAudioStreamDes.mBytesPerPacket = 0;
    outAudioStreamDes.mFramesPerPacket = 1024;
    outAudioStreamDes.mBytesPerFrame = 0;
    outAudioStreamDes.mChannelsPerFrame = 1;
    outAudioStreamDes.mBitsPerChannel = 0;
    outAudioStreamDes.mReserved = 0;
    AudioClassDescription *des = [self getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC
                                                       fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    OSStatus status = AudioConverterNewSpecific(&inAudioStreamDes, &outAudioStreamDes, 1, des, &miAudioConvert);
    if (status != 0) {
        NSLog(@"create convert failed...\n");
    }
    
    UInt32 targetSize   = sizeof(outAudioStreamDes);
    UInt32 bitRate  =  64000;
    targetSize      = sizeof(bitRate);
    status          = AudioConverterSetProperty(miAudioConvert,
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
- (void)encodePCMToAAC:(MIAudioQueueConvert *)convert
{
    if (initTime == 0) {
        initTime = 1;
        [self settingDestAudioStreamDescription];
    }
    OSStatus status;
    memset(_aacBuffer, 0, _aacBufferSize);
    
    AudioBufferList *bufferList             = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers              = 1;
    bufferList->mBuffers[0].mNumberChannels = outAudioStreamDes.mChannelsPerFrame;
    bufferList->mBuffers[0].mData           = _aacBuffer;
    bufferList->mBuffers[0].mDataByteSize   = (int)_aacBufferSize;
    
    AudioStreamPacketDescription outputPacketDescriptions;
    UInt32 inNumPackets = 1;
    status = AudioConverterFillComplexBuffer(miAudioConvert,
                                             pcmEncodeConverterInputCallback,
                                             (__bridge void *)(self),//inBuffer->mAudioData,
                                             &inNumPackets,
                                             bufferList,
                                             &outputPacketDescriptions);
    
    if (status == noErr) {
        NSData *aacData = [NSData dataWithBytes:bufferList->mBuffers[0].mData length:bufferList->mBuffers[0].mDataByteSize];
        static int createCount = 0;
        static FILE *fp_aac = NULL;
        if (createCount == 0) {
            NSString *paths = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *debugUrl = [paths stringByAppendingPathComponent:@"debug"] ;
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager createDirectoryAtPath:debugUrl withIntermediateDirectories:YES attributes:nil error:nil];
            
            NSString *audioFile = [paths stringByAppendingPathComponent:@"debug/queue_aac_48k.aac"] ;
            fp_aac = fopen([audioFile UTF8String], "wb++");
        }
        createCount++;
        if (createCount <= 800) {
            NSData *rawAAC = [NSData dataWithBytes:bufferList->mBuffers[0].mData length:bufferList->mBuffers[0].mDataByteSize];
            NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
            NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
            [fullData appendData:rawAAC];
            
            void * bufferData = fullData.bytes;
            int buffersize = fullData.length;
            
            fwrite((uint8_t *)bufferData, 1, buffersize, fp_aac);
        }else{
            fclose(fp_aac);
            NSLog(@"AudioQueue, close aac file ");
            [self stopRecorder];
            createCount = 0;
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

- (NSData*)adtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 3;  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}
    

@end
