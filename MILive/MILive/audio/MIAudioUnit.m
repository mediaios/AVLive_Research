//
//  MIAudioUnit.m
//  MILive
//
//  Created by mediaios on 2019/5/16.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIAudioUnit.h"
#import "MIConst.h"

// Audio Unit Set Property
#define INPUT_BUS  1      ///< A I/O unit's bus 1 connects to input hardware (microphone).
#define OUTPUT_BUS 0      ///< A I/O unit's bus 0 connects to output hardware (speaker)


static OSStatus RecordCallBack (void *                            inRefCon,
                                AudioUnitRenderActionFlags *    ioActionFlags,
                                const AudioTimeStamp *            inTimeStamp,
                                UInt32                            inBusNumber,
                                UInt32                            inNumberFrames,
                                AudioBufferList * __nullable    ioData)
{
    NSLog(@"%s",__func__);
    MIAudioUnit *recorder = (__bridge MIAudioUnit *)inRefCon;

    AudioUnitRender(recorder->m_audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, recorder->m_audioBufferList);

    void *bufferData = recorder->m_audioBufferList->mBuffers[0].mData;
    UInt32 buffersize = recorder->m_audioBufferList->mBuffers[0].mDataByteSize;

    NSLog(@"QiDebug, buffersize:%d",buffersize);

    static int createCount = 0;
    static FILE *fp_pcm = NULL;
    if (createCount == 0) {
        NSString *paths = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *debugUrl = [paths stringByAppendingPathComponent:@"debug"] ;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager createDirectoryAtPath:debugUrl withIntermediateDirectories:YES attributes:nil error:nil];

        NSString *audioFile = [paths stringByAppendingPathComponent:@"debug/unit1_pcm_48k.pcm"] ;
        fp_pcm = fopen([audioFile UTF8String], "wb++");
    }
    createCount++;
    fwrite((uint8_t *)bufferData, 1, buffersize, fp_pcm);

    if (createCount > 500) {
        fclose(fp_pcm);
        NSLog(@"AudioUnit, close PCM file ");
        [recorder stopAudioUnitRecorder];
    }
    
    return 0;
}



@implementation MIAudioUnit

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
        dataFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        dataFormat.mBitsPerChannel = 16;
        dataFormat.mBytesPerPacket = dataFormat.mBytesPerFrame = (dataFormat.mBitsPerChannel / 8) * dataFormat.mChannelsPerFrame;
        dataFormat.mFramesPerPacket = kAudioQueueRecorderPCMFramesPerPacket; // AudioQueue collection pcm data , need to set as this
    }
}

- (NSString *)freeAudioUnit
{
    if (!m_audioUnit) {
        return @"AudioUnit is  NULL , don,t need to free";
    }
    [self stopAudioUnitRecorder];
    OSStatus status = AudioUnitUninitialize(m_audioUnit);
    if (status != noErr) {
        return [NSString stringWithFormat:@"AudioUnitUninitialize failed:%d",status];
    }
    OSStatus result =  AudioComponentInstanceDispose(m_audioUnit);
    if (result != noErr) {
        return [NSString stringWithFormat:@"AudioComponentInstanceDispose failed. status : %d \n",result];
    }else{
        
    }
    m_audioUnit = nil;
    return @"AudioUnit object free";
}

- (void)startAudioUnitRecorder
{
    OSStatus status;
    if (self.m_isRunning) {
        return;
    }
    
    if (!m_audioUnit) {
        [self initAudioComponent];
        [self initBuffer];
        [self setingAudioUnitPropertyAndFormat];
        [self initRecordeCallback];
        
        status = AudioUnitInitialize(m_audioUnit);
        if (status != noErr) {
            NSLog(@"AudioUnit, couldn't initialize AURemoteIO instance, status : %d ",status);
        }
    }
    
    status  = AudioOutputUnitStart(m_audioUnit);
    if (status == noErr) {
        self.m_isRunning = YES;
    }else{
        self.m_isRunning = NO;
        NSString *errorInfo = [self freeAudioUnit];
        NSLog(@"AudioUnit: %@",errorInfo);
    }
}

- (void)stopAudioUnitRecorder
{
    if (self.m_isRunning == NO) {
        return;
    }
    self.m_isRunning = NO;
    if (m_audioUnit != NULL) {
        OSStatus status = AudioOutputUnitStop(m_audioUnit);
        if (status) {
            NSLog(@"AudioUnit, stop AudioUnit failed.\n");
        }else{
            NSLog(@"AudioUnit, stop AudioUnit success.\n");
        }
    }
    
}

- (void)initAudioComponent
{
    OSStatus status;
    AudioComponentDescription audioDesc;
    audioDesc.componentType         = kAudioUnitType_Output;
    audioDesc.componentSubType      = kAudioUnitSubType_VoiceProcessingIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags        = 0;
    audioDesc.componentFlagsMask    = 0;
    
    AudioComponent inputComponent   = AudioComponentFindNext(NULL, &audioDesc);
    status = AudioComponentInstanceNew(inputComponent, &m_audioUnit);
    if (status != noErr) {
        m_audioUnit = nil;
        NSLog(@"AudioUnit, couldn't create AudioUnit instance ");
    }
}

- (void)initBuffer {
    // Disable AU buffer allocation for the recorder, we allocate our own.
    UInt32 flag     = 0;
    OSStatus status = AudioUnitSetProperty(m_audioUnit,
                                           kAudioUnitProperty_ShouldAllocateBuffer,
                                           kAudioUnitScope_Output,
                                           INPUT_BUS,
                                           &flag,
                                           sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnit,couldn't AllocateBuffer of AudioUnitCallBack, status : %d",status);
    }
    m_audioBufferList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    m_audioBufferList->mNumberBuffers               = 1;
    m_audioBufferList->mBuffers[0].mNumberChannels  = dataFormat.mChannelsPerFrame;
    m_audioBufferList->mBuffers[0].mDataByteSize    = kAudioRecoderPCMMaxBuffSize * sizeof(short);
    m_audioBufferList->mBuffers[0].mData            = (short *)malloc(sizeof(short) * kAudioRecoderPCMMaxBuffSize);

}

- (void)setingAudioUnitPropertyAndFormat
{
    OSStatus status;
    [self setUpAudioQueueWithFormatID:kAudioFormatLinearPCM];
    
    status = AudioUnitSetProperty(m_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output, 
                                  INPUT_BUS,
                                  &dataFormat,
                                  sizeof(dataFormat));
    if (status != noErr) {
        NSLog(@"AudioUnit,couldn't set the input client format on AURemoteIO, status : %d ",status);
    }
    
    UInt32 flag = 1;
    status = AudioUnitSetProperty(m_audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  INPUT_BUS,
                                  &flag,
                                  sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnit,could not enable input on AURemoteIO, status : %d ",status);
    }
    
    /*
     https://blog.csdn.net/f_season/article/details/82981333
     关闭播放的enableIO
     */
    flag = 0;
    status = AudioUnitSetProperty(m_audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  OUTPUT_BUS,
                                  &flag,
                                  sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnit,could not enable output on AURemoteIO, status : %d  ",status);
    }
}

- (void)initRecordeCallback {
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc        = RecordCallBack;
    recordCallback.inputProcRefCon  = (__bridge void *)self;
    OSStatus status                 = AudioUnitSetProperty(m_audioUnit,
                                                           kAudioOutputUnitProperty_SetInputCallback,
                                                           kAudioUnitScope_Global,
                                                           INPUT_BUS,
                                                           &recordCallback,
                                                           sizeof(recordCallback));
    
    if (status != noErr) {
        NSLog(@"AudioUnit, Audio Unit set record Callback failed, status : %d ",status);
    }
}

// https://blog.csdn.net/f_season/article/details/82981333
@end
