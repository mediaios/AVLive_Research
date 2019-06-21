//
//  MIHWH264Encoder.m
//  MILive
//
//  Created by mediaios on 2019/5/30.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIHWH264Encoder.h"


void  miEncoderVideoCallBack(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer)
{
    NSLog(@"%s",__func__);
    if (status != noErr) {
        NSLog(@"AppHWH264Encoder, encoder failed, res=%d",status);
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"AppHWH264Encoder, samplebuffer is not ready");
        return;
    }
    
    MIHWH264Encoder *encoder = (__bridge MIHWH264Encoder*)outputCallbackRefCon;
    
    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    BOOL isKeyframe = false;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if(attachments != NULL)
    {
        CFDictionaryRef attachment =(CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFBooleanRef dependsOnOthers = (CFBooleanRef)CFDictionaryGetValue(attachment, kCMSampleAttachmentKey_DependsOnOthers);
        isKeyframe = (dependsOnOthers == kCFBooleanFalse);
    }
    
    if(isKeyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t spsSize, ppsSize;
        size_t parmCount;
        const uint8_t*sps, *pps;
        
        int NALUnitHeaderLengthOut;
        
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sps, &spsSize, &parmCount, &NALUnitHeaderLengthOut );
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pps, &ppsSize, &parmCount, &NALUnitHeaderLengthOut );
        
        uint8_t *spsppsNALBuff = (uint8_t*)malloc(spsSize+4+ppsSize+4);
        memcpy(spsppsNALBuff, "\x00\x00\x00\x01", 4);
        memcpy(&spsppsNALBuff[4], sps, spsSize);
        memcpy(&spsppsNALBuff[4+spsSize], "\x00\x00\x00\x01", 4);
        memcpy(&spsppsNALBuff[4+spsSize+4], pps, ppsSize);
        NSLog(@"AppHWH264Encoder, encoder video ,find IDR frame");
        //        AVFormatControl::GetInstance()->addH264Data(spsppsNALBuff, (int)(spsSize+ppsSize+8), dtsAfter, YES, NO);
        
        [encoder.delegate acceptEncoderData:spsppsNALBuff length:(int)(spsSize+ppsSize + 8) naluType:H264Data_NALU_TYPE_IDR];
    }
    
    size_t blockBufferLength;
    uint8_t *bufferDataPointer = NULL;
    CMBlockBufferGetDataPointer(block, 0, NULL, &blockBufferLength, (char **)&bufferDataPointer);
    
    const size_t startCodeLength = 4;
    static const uint8_t startCode[] = {0x00, 0x00, 0x00, 0x01};
    
    size_t bufferOffset = 0;
    static const int AVCCHeaderLength = 4;
    while (bufferOffset < blockBufferLength - AVCCHeaderLength)
    {
        uint32_t NALUnitLength = 0;
        memcpy(&NALUnitLength, bufferDataPointer+bufferOffset, AVCCHeaderLength);
        NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
        memcpy(bufferDataPointer+bufferOffset, startCode, startCodeLength);
        bufferOffset += AVCCHeaderLength + NALUnitLength;
    }
    
    //    AVFormatControl::GetInstance()->addH264Data(bufferDataPointer, (int)blockBufferLength,dtsAfter, NO, isKeyframe);
    
    [encoder.delegate acceptEncoderData:bufferDataPointer length:(int)blockBufferLength naluType:H264Data_NALU_TYPE_NOIDR];
    
}



@interface MIHWH264Encoder()
@property (nonatomic,assign) BOOL isInitHWH264Encoder;
@end

@implementation MIHWH264Encoder
- (instancetype)init
{
    self = [super init];
    if (self) {
        _width  = 1080;
        _height = 1920;
        _fps     = 30;
        compressionSession = NULL;
        _isInitHWH264Encoder = NO;
    }
    return self;
}

static MIHWH264Encoder *miHWEncoder_Instance = NULL;

+ (instancetype)getInstance
{
    if (miHWEncoder_Instance == NULL) {
        miHWEncoder_Instance = [[MIHWH264Encoder alloc] init];
    }
    return miHWEncoder_Instance;
}

- (void)settingEncoderParametersWithWidth:(int)width height:(int)height fps:(int)fps
{
    self.width  = width;
    self.height = height;
    self.fps    = fps;
}


- (void)prepareForEncoder
{
    if (self.width == 0 || self.height == 0) {
        NSLog(@"AppHWH264Encoder, VTSession need width and height for init, width = %d, height = %d",self.width,self.height);
        return;
    }
    
    [m_lock lock];
    OSStatus status =  noErr;
    status =  VTCompressionSessionCreate(NULL, self.width, self.height, kCMVideoCodecType_H264, NULL, NULL, NULL, miEncoderVideoCallBack, (__bridge void *)self, &compressionSession);
    if (status != noErr) {
        NSLog(@"AppHWH264Encoder , create encoder session failed,res=%d",status);
        return;
    }
    
    if (self.fps) {
        int v = self.fps;
        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
        status = VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, ref);
        CFRelease(ref);
        if (status != noErr) {
            NSLog(@"AppHWH264Encoder, create encoder session failed, fps=%d,res=%d",self.fps,status);
            return;
        }
    }
    
    if (self.bitrate) {
        int v = self.bitrate;
        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
        status = VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate,ref);
        CFRelease(ref);
        if (status != noErr) {
            NSLog(@"AppHWH264Encoder, create encoder session failed, bitrate=%d,res=%d",self.bitrate,status);
            return;
        }
    }
    
    status  = VTCompressionSessionPrepareToEncodeFrames(compressionSession);
    if (status != noErr) {
        NSLog(@"AppHWH264Encoder, create encoder session failed,res=%d",status);
        return;
    }
    
}

- (void)encoder:(CMSampleBufferRef)sampleBuffer
{
    if (!self.isInitHWH264Encoder) {
        [self prepareForEncoder];
        self.isInitHWH264Encoder = YES;
    }
    CVImageBufferRef imageBuffer  = CMSampleBufferGetImageBuffer(sampleBuffer);
    CMTime presentationTime       = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    OSStatus status = VTCompressionSessionEncodeFrame(compressionSession, imageBuffer, presentationTime, kCMTimeInvalid, NULL, NULL, NULL);
    if (status != noErr) {
        VTCompressionSessionInvalidate(compressionSession);
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);
        CFRelease(compressionSession);
        compressionSession = NULL;
        self.isInitHWH264Encoder = NO;
        NSLog(@"AppHWH264Encoder, encoder failed");
        return;
    }
    
}

@end
