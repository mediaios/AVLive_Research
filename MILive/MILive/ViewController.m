//
//  ViewController.m
//  MILive
//
//  Created by mediaios on 2019/5/11.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "ViewController.h"


static OSStatus audioUnitRecordCallBack (void *                            inRefCon,
                                         AudioUnitRenderActionFlags *    ioActionFlags,
                                         const AudioTimeStamp *            inTimeStamp,
                                         UInt32                            inBusNumber,
                                         UInt32                            inNumberFrames,
                                         AudioBufferList * __nullable    ioData)
{
    NSLog(@"%s",__func__);
    ViewController *recorder = (__bridge ViewController *)inRefCon;
    
    AudioUnitRender(recorder->miIoUnitInstance, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, recorder->audioBufferList);
    
    void *bufferData = recorder->audioBufferList->mBuffers[0].mData;
    UInt32 buffersize = recorder->audioBufferList->mBuffers[0].mDataByteSize;
    
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
    
    if (createCount > 200) {
        fclose(fp_pcm);
        NSLog(@"AudioUnit, close PCM file ");
        [recorder stop];
    }
    
    return 0;
}




@interface ViewController ()


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    return;
    [self miInitAudioUnit];
    [self start];
}

- (void)miInitAudioUnit
{
    /*
     类型是kAudioUnitType_Output，主要提供的是I/O的功能，其子类型说明如下：
     
     RemoteIO: 子类型是kAudioUnitSubType_RemoteIO，用来采集音频与播放音频的，其实当开发者的应用场景中要使用麦克风及扬声器的时候回用到该AudioUnit
     Generic Output：子类型是kAudioUnitSubType_GenericOutput，当开发者需要进行离线处理，或者说在AUGraph中不使用Speaker（扬声器）来驱动整个数据流，而是希望使用一个输出（可以放入内存队列或者进行磁盘I/O操作）来驱动数据流时，就使用该子类型
     */
    AudioComponentDescription auDesc;
    auDesc.componentType = kAudioUnitType_Output;
    auDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    auDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    auDesc.componentFlags = 0;
    auDesc.componentFlagsMask = 0;
    AudioComponent foundIoUnitReference = AudioComponentFindNext(NULL, &auDesc);
    AudioComponentInstanceNew(foundIoUnitReference, &miIoUnitInstance);
    
    
    
    
    /* setting audio stream format */
    AudioStreamBasicDescription audioFormat;
    
    UInt32 size = sizeof(audioFormat.mSampleRate);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                            &size,
                            &audioFormat.mSampleRate);
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mSampleRate = 48000;
    
    size = sizeof(audioFormat.mChannelsPerFrame);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels,
                            &size,
                            &audioFormat.mChannelsPerFrame);
    
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame = (audioFormat.mBitsPerChannel / 8) * audioFormat.mChannelsPerFrame;
    audioFormat.mFramesPerPacket = 1;
    
    OSStatus status = AudioUnitSetProperty(miIoUnitInstance,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Output,
                                           1,
                                           &audioFormat,
                                           sizeof(audioFormat));
    if (status != noErr) {
        NSLog(@"AudioUnit,couldn't set the input client format on AURemoteIO, status : %d ",status);
    }
    
    
    
    /*** setting audiounit property ***/
    
    // enable input
    UInt32 flag = 1;
    status = AudioUnitSetProperty(miIoUnitInstance,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  1,
                                  &flag,
                                  sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnit, enable input failed...");
        return;
    }
    
    // disable output
    flag = 0;
    status = AudioUnitSetProperty(miIoUnitInstance,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  0,
                                  &flag,
                                  sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnit, disable output failed...");
        return;
    }
    
    // Disable AU buffer allocation for the recorder, we allocate our own.
    flag     = 0;
    status = AudioUnitSetProperty(miIoUnitInstance,
                                  kAudioUnitProperty_ShouldAllocateBuffer,
                                  kAudioUnitScope_Output,
                                  1,
                                  &flag,
                                  sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnit,couldn't AllocateBuffer of AudioUnitCallBack, status : %d",status);
    }
    audioBufferList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    audioBufferList->mNumberBuffers               = 1;
    audioBufferList->mBuffers[0].mNumberChannels  = audioFormat.mChannelsPerFrame;
    audioBufferList->mBuffers[0].mDataByteSize    = 2048 * sizeof(short);
    audioBufferList->mBuffers[0].mData            = (short *)malloc(sizeof(short) * 2048);
    
    
    // add output callback
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc        = audioUnitRecordCallBack;
    recordCallback.inputProcRefCon  = (__bridge void *)self;
    status                 = AudioUnitSetProperty(miIoUnitInstance,
                                                  kAudioOutputUnitProperty_SetInputCallback,
                                                  kAudioUnitScope_Global,
                                                  1,
                                                  &recordCallback,
                                                  sizeof(recordCallback));
    
    if (status != noErr) {
        NSLog(@"AudioUnit, Audio Unit set record Callback failed, status : %d ",status);
    }
    
}

- (void)start
{
    OSStatus status  = AudioOutputUnitStart(miIoUnitInstance);
    if (status == noErr) {
        NSLog(@"开启audio unit成功");
    }else{
        NSLog(@"开启audio unit失败");
    }
}

- (void)stop
{
    OSStatus status = AudioOutputUnitStop(miIoUnitInstance);
    if (status) {
        NSLog(@"AudioUnit, stop AudioUnit failed.\n");
    }else{
        NSLog(@"AudioUnit, stop AudioUnit success.\n");
    }
}


@end

