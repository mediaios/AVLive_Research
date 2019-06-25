//
//  MIRtpmClient.m
//  MILive
//
//  Created by mediaios on  2019/6/21.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIRtpmClient.h"
#define RTMP_HEAD_SIZE (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)

#define SAVC(x)    static const AVal av_##x = AVC(#x)

static const AVal av_setDataFrame = AVC("@setDataFrame");
SAVC(onMetaData);
SAVC(duration);
SAVC(width);
SAVC(height);
SAVC(videocodecid);
SAVC(videodatarate);
SAVC(framerate);
SAVC(audiocodecid);
SAVC(audiodatarate);
SAVC(audiosamplerate);
SAVC(audiosamplesize);
SAVC(audiochannels);
SAVC(stereo);
SAVC(encoder);
SAVC(av_stereo);
SAVC(fileSize);
SAVC(avc1);
SAVC(mp4a);

static const AVal av_SDKVersion = AVC("meidaios 1.0.0");

@interface MIRtpmClient ()
@property (nonatomic,copy) NSString* rtmpUrl;
@property (nonatomic) dispatch_queue_t rtmpQueue;

@end

@implementation MIRtpmClient

- (dispatch_queue_t)rtmpQueue
{
    if (!_rtmpQueue) {
        _rtmpQueue = dispatch_queue_create("rtmpQueue", DISPATCH_QUEUE_SERIAL);
    }
    return _rtmpQueue;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
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
    int ret = RTMP_SetupURL(self->rtmp, (char*)[_rtmpUrl cStringUsingEncoding:NSASCIIStringEncoding]);
    if (ret < 0)
    {
        NSLog(@"fail");
        RTMP_Free(self->rtmp);
        return NO;
    }
    
    //设置可写，即发布流，这个函数必须在连接前使用，否则无效
    RTMP_EnableWrite(self->rtmp);
    //设置失败
    
    //连接服务器
    if (RTMP_Connect(self->rtmp, NULL) < 0){
        NSLog(@"fail");
        
        RTMP_Free(self->rtmp);
        return NO;
    }
    //连接流
    if (RTMP_ConnectStream(self->rtmp, 0) == FALSE) {
        NSLog(@"fail");
        RTMP_Free(self->rtmp);
        return NO;
    }
    
    [self sendMetaData];
    self->start_time = [[NSDate date] timeIntervalSince1970]*1000;
    return YES;
}

- (void)sendMetaData {
    RTMPPacket packet;
    
    char pbuf[2048], *pend = pbuf+sizeof(pbuf);
    
    packet.m_nChannel = 0x03;     // control channel (invoke)
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = RTMP_PACKET_TYPE_INFO;
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = self->rtmp->m_stream_id;
    packet.m_hasAbsTimestamp = TRUE;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;
    
    char *enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_setDataFrame);
    enc = AMF_EncodeString(enc, pend, &av_onMetaData);
    
    *enc++ = AMF_OBJECT;
    
    enc = AMF_EncodeNamedNumber(enc, pend, &av_duration,        0.0);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_fileSize,        0.0);
    
    // videosize
    enc = AMF_EncodeNamedNumber(enc, pend, &av_width,           480);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_height,          640);
    
    // video
    enc = AMF_EncodeNamedString(enc, pend, &av_videocodecid,    &av_avc1);
    //640x480
    enc = AMF_EncodeNamedNumber(enc, pend, &av_videodatarate,   480 * 640  / 1000.f);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_framerate,       20);
    
    // audio
    enc = AMF_EncodeNamedString(enc, pend, &av_audiocodecid,    &av_mp4a);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiodatarate,   96000);
    
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiosamplerate, 44100);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiosamplesize, 16.0);
    enc = AMF_EncodeNamedBoolean(enc, pend, &av_stereo,     NO);
    
    // sdk version
    enc = AMF_EncodeNamedString(enc, pend, &av_encoder,         &av_SDKVersion);
    
    *enc++ = 0;
    *enc++ = 0;
    *enc++ = AMF_OBJECT_END;
    
    packet.m_nBodySize = enc - packet.m_body;
    if(!RTMP_SendPacket(self->rtmp, &packet, FALSE)) {
        return;
    }
}

- (BOOL)stopRtmpConnect
{
    if (self->rtmp)
    {
        RTMP_Close(self->rtmp);
        RTMP_Free(self->rtmp);
        return YES;
    }
    return NO;
}


- (void)sendVideoData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame
{
    __block uint32_t length = data.length;
    dispatch_async(self.rtmpQueue, ^{
        if(self->rtmp != NULL)
        {
            uint32_t timeoffset = [[NSDate date] timeIntervalSince1970]*1000 - self->start_time;  /*start_time为开始直播时的时间戳*/
            NSInteger i = 0;
            NSInteger rtmpLength = data.length + 9;
            unsigned char *body = (unsigned char *)malloc(rtmpLength);
            memset(body, 0, rtmpLength);
            
            if (isKeyFrame) {
                body[i++] = 0x17;        // 1:Iframe  7:AVC
            } else {
                body[i++] = 0x27;        // 2:Pframe  7:AVC
            }
            body[i++] = 0x01;    // AVCPacketType:   0 表示AVC sequence header; 1 表示AVC NALU; 2 表示AVC end of sequence....
            body[i++] = 0x00;    // CompositionTime，占3个字节: 1表示 Composition time offset; 其它情况都是0
            body[i++] = 0x00;
            body[i++] = 0x00;
            body[i++] = (data.length >> 24) & 0xff;  // NALU size
            body[i++] = (data.length >> 16) & 0xff;
            body[i++] = (data.length >>  8) & 0xff;
            body[i++] = (data.length) & 0xff;
            memcpy(&body[i], data.bytes, data.length);  // NALU data
            
            [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:timeoffset];
            free(body);
        }
    });
}

- (void)sendVideoSps:(NSData *)spsData pps:(NSData *)ppsData
{
    unsigned char* sps = (unsigned char*)spsData.bytes;
    unsigned char* pps = (unsigned char*)ppsData.bytes;
    long sps_len = spsData.length;
    long pps_len = ppsData.length;
    dispatch_async(self.rtmpQueue, ^{
        if(self->rtmp!= NULL)
        {
            unsigned char *body = NULL;
            NSInteger iIndex = 0;
            NSInteger rtmpLength = 1024;
            
            body = (unsigned char *)malloc(rtmpLength);
            memset(body, 0, rtmpLength);
            
            /*** VideoTagHeader: 编码格式为AVC时，该header长度为5 ***/
            body[iIndex++] = 0x17;   // 表示帧类型和CodecID,各占4个bit加一起是1个Byte   1: 表示帧类型，当前是I帧(for AVC, A seekable frame)  7: AVC  元数据当做I帧发送
            body[iIndex++] = 0x00;   // AVCPacketType: 0 = AVC sequence header, 长度为1
            
            body[iIndex++] = 0x00;   // CompositionTime: 0  ,长度为3
            body[iIndex++] = 0x00;
            body[iIndex++] = 0x00;
            
            /*** AVCDecoderConfigurationRecord:包含着H.264解码相关比较重要的sps,pps信息，在给AVC解码器送数据流之前一定要把sps和pps信息先发送，否则解码器不能正常work，而且在
             解码器stop之后再次start之前，如seek，快进快退状态切换等都需要重新发送一遍sps和pps信息。AVCDecoderConfigurationRecord在FLV文件中一般情况也是出现1次，也就是第一个
             video tag.
             ***/
            body[iIndex++] = 0x01;        // 版本 = 1
            body[iIndex++] = sps[1];      // AVCProfileIndication,1个字节长度:
            body[iIndex++] = sps[2];      // profile_compatibility,1个字节长度
            body[iIndex++] = sps[3];      // AVCLevelIndication , 1个字节长度
            body[iIndex++] = 0xff;
            
            // sps
            body[iIndex++] = 0xe1;    // 它的后5位表示SPS数目， 0xe1 = 1110 0001 后五位为 00001 = 1，表示只有1个SPS
            body[iIndex++] = (sps_len >> 8) & 0xff;  // 表示SPS长度：2个字节 ，其存储的就是sps_len (策略：sps长度右移8位&0xff,然后sps长度&0xff)
            body[iIndex++] = sps_len & 0xff;
            memcpy(&body[iIndex], sps, sps_len);
            iIndex += sps_len;
            
            // pps
            body[iIndex++] = 0x01;   // 表示pps的数目，当前表示只有1个pps
            body[iIndex++] = (pps_len >> 8) & 0xff;  // 和sps同理，表示pps的长度：占2个字节 ...
            body[iIndex++] = (pps_len) & 0xff;
            memcpy(&body[iIndex], pps, pps_len);
            iIndex += pps_len;
            
            [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex nTimestamp:0];
            free(body);
        }
    });
}

- (void)sendAudioHeader:(NSData *)data{
    
    NSInteger audioLength = data.length;
    dispatch_async(self.rtmpQueue, ^{
        NSInteger rtmpLength = audioLength + 2;     /*spec data长度,一般是2*/
        unsigned char *body = (unsigned char *)malloc(rtmpLength);
        memset(body, 0, rtmpLength);
        
        /*AF 00 + AAC RAW data*/
        body[0] = 0xAE;    // 4bit表示音频格式， 10表示AAC，所以用A来表示。  A: 表示发送的是AAC ； SountRate占2bit,此处是44100用3表示，转化为二进制位 11 ； SoundSize占1个bit,0表示8位，1表示16位，此处是16位用1表示，二进制表示为 1； SoundType占1个bit,0表示单声道，1表示立体声，此处是立体声用1表示，二进制表示为 0； 1111 = F
        body[1] = 0x00;  // 0表示的是audio的配置
        memcpy(&body[2], data.bytes, audioLength);          /*spec_buf是AAC sequence header数据*/
        [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:0];
        free(body);
    });
}

- (void)sendAudioData:(NSData *)data{
    NSInteger audioLength = data.length;
    dispatch_async(self.rtmpQueue, ^{
        uint32_t timeoffset = [[NSDate date] timeIntervalSince1970]*1000 - self->start_time;
        NSInteger rtmpLength = audioLength + 2;    /*spec data长度,一般是2*/
        unsigned char *body = (unsigned char *)malloc(rtmpLength);
        memset(body, 0, rtmpLength);
        
        /*AF 01 + AAC RAW data*/
        body[0] = 0xAE;
        body[1] = 0x01;
        memcpy(&body[2], data.bytes, audioLength);
        [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:timeoffset];
        free(body);
    });
}

-(NSInteger)sendPacket:(unsigned int)nPacketType data:(unsigned char *)data size:(NSInteger) size nTimestamp:(uint64_t) nTimestamp
{
    NSInteger rtmpLength = size;
    RTMPPacket rtmp_pack;
    RTMPPacket_Reset(&rtmp_pack);
    RTMPPacket_Alloc(&rtmp_pack,(uint32_t)rtmpLength);
    
    rtmp_pack.m_nBodySize = (uint32_t)size;
    memcpy(rtmp_pack.m_body,data,size);
    rtmp_pack.m_hasAbsTimestamp = 0;
    rtmp_pack.m_packetType = nPacketType;
    if(self->rtmp) rtmp_pack.m_nInfoField2 = self->rtmp->m_stream_id;
    rtmp_pack.m_nChannel = 0x04;
    rtmp_pack.m_headerType = RTMP_PACKET_SIZE_LARGE;
    if (RTMP_PACKET_TYPE_AUDIO == nPacketType && size !=4){
        rtmp_pack.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    }
    rtmp_pack.m_nTimeStamp = (uint32_t)nTimestamp;
    
    NSInteger nRet = [self RtmpPacketSend:&rtmp_pack];
    
    RTMPPacket_Free(&rtmp_pack);
    return nRet;
}

- (NSInteger)RtmpPacketSend:(RTMPPacket*)packet{
    //    RTMPError error;
    if (RTMP_IsConnected(self->rtmp)){
        int success = RTMP_SendPacket(self->rtmp,packet,0);
        //        if(success){
        //            self.isSending = NO;
        //            [self sendFrame];
        //        }
        return success;
    }
    
    return -1;
}





@end
