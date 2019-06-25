//
//  PSHWH264Encoder.m
//  MILive
//
//  Created by ethan on 2019/6/25.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "PSHWH264Encoder.h"


void  psEncoderVideoCallBack(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer)
{
    if (status != noErr) {
        NSLog(@"AppHWH264Encoder, encoder failed, res=%d",status);
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"AppHWH264Encoder, samplebuffer is not ready");
        return;
    }
    
    PSHWH264Encoder *encoder = (__bridge PSHWH264Encoder*)outputCallbackRefCon;
    
    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    BOOL isKeyframe = false;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if(attachments != NULL)
    {
        CFDictionaryRef attachment =(CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFBooleanRef dependsOnOthers = (CFBooleanRef)CFDictionaryGetValue(attachment, kCMSampleAttachmentKey_DependsOnOthers);
        isKeyframe = (dependsOnOthers == kCFBooleanFalse);
    }
    
    if(isKeyframe && !encoder.sps)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t spsSize, ppsSize;
        size_t parmCount;
        const uint8_t *spsBuf, *ppsBuf;
        
        int NALUnitHeaderLengthOut;
        
        // GET SPS PPS INFO
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &spsBuf, &spsSize, &parmCount, &NALUnitHeaderLengthOut );
        if (status == noErr) {
            statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &ppsBuf, &ppsSize, &parmCount, &NALUnitHeaderLengthOut );
            NSData *sps = [NSData dataWithBytes:spsBuf length:spsSize];
            NSData *pps = [NSData dataWithBytes:ppsBuf length:ppsSize];
            encoder.sps = sps;
            encoder.pps = pps;
            
            [encoder.delegate videoEncoder:encoder sps:sps pps:pps];
        }
        NSLog(@"AppHWH264Encoder, encoder video ,find IDR frame,spsSize:%ld, ppsSize:%ld",spsSize,ppsSize);
    }
    
    size_t blockBufferLength;
    uint8_t *bufferDataPointer = NULL;
    CMBlockBufferGetDataPointer(block, 0, NULL, &blockBufferLength, (char **)&bufferDataPointer);
    
    size_t bufferOffset = 0;
    static const int AVCCHeaderLength = 4;
    while (bufferOffset < blockBufferLength - AVCCHeaderLength)
    {
        uint32_t NALUnitLength = 0;
        memcpy(&NALUnitLength, bufferDataPointer+bufferOffset, AVCCHeaderLength);
        NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
        
        NSData *data = [[NSData alloc] initWithBytes:(bufferDataPointer+bufferOffset+AVCCHeaderLength) length:NALUnitLength];
        [encoder.delegate videoEncoder:encoder videoData:data isKeyFrame:isKeyframe];
        bufferOffset += AVCCHeaderLength + NALUnitLength;
    }
    
}



@interface PSHWH264Encoder()
@property (nonatomic,assign) BOOL isInitHWH264Encoder;
@end

@implementation PSHWH264Encoder
- (instancetype)init
{
    self = [super init];
    if (self) {
        _width  = 480;
        _height = 640;
        _fps     = 30;
        compressionSession = NULL;
        _isInitHWH264Encoder = NO;
    }
    return self;
}

static PSHWH264Encoder *psHWEncoder_Instance = NULL;

+ (instancetype)getInstance
{
    if (psHWEncoder_Instance == NULL) {
        psHWEncoder_Instance = [[PSHWH264Encoder alloc] init];
    }
    return psHWEncoder_Instance;
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
    status =  VTCompressionSessionCreate(NULL, self.width, self.height, kCMVideoCodecType_H264, NULL, NULL, NULL, psEncoderVideoCallBack, (__bridge void *)self, &compressionSession);
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
        NSArray *limit = @[@(self.bitrate * 1.5/8), @(1)];
        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        CFRelease(ref);
        if (status != noErr) {
            NSLog(@"AppHWH264Encoder, create encoder session failed, bitrate=%d,res=%d",self.bitrate,status);
            return;
        }
    }
    
    int frameInterval = 30;
    CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    
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
