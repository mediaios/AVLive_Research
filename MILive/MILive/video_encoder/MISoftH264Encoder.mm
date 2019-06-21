//
//  MISoftH264Encoder.m
//  MILive
//
//  Created by mediaios on 2019/5/30.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MISoftH264Encoder.h"



@implementation MISoftH264Encoder
{
    AVFormatContext             *pFormatCtx;
    AVOutputFormat              *out_fmt;
    AVStream                    *video_stream;
    AVCodecContext              *pCodecCtx;
    AVCodec                     *pCodec;
    AVPacket                    pkt;
    uint8_t                     *picture_buf;
    AVFrame                     *pFrame;
    int                         picture_size;
    int                         y_size;
    int                         framecnt;
    char                        *out_file;
    
    int                         encoder_h264_frame_width;
    int                         encoder_h264_frame_height;
}

- (instancetype)init
{
    if (self = [super init]) {

    }
    return self;
}

static MISoftH264Encoder *miSoftEncoder_Instance = nil;
+ (instancetype)getInstance
{
    if (miSoftEncoder_Instance == NULL) {
        miSoftEncoder_Instance = [[MISoftH264Encoder alloc] init];
    }
    return miSoftEncoder_Instance;
}

- (void)setFileSavedPath:(NSString *)path
{
    NSUInteger len = [path length];
    char *filepath = (char*)malloc(sizeof(char) * (len + 1));
    [path getCString:filepath maxLength:len + 1 encoding:[NSString defaultCStringEncoding]];
    out_file = filepath;
}

- (int)setEncoderVideoWidth:(int)width height:(int)height bitrate:(int)bitrate
{
    framecnt = 0;
    encoder_h264_frame_width = width;
    encoder_h264_frame_height = height;
    av_register_all();
    pFormatCtx = avformat_alloc_context();
    
    // 设置输出文件的路径
    out_fmt = av_guess_format(NULL, out_file, NULL);
    pFormatCtx->oformat = out_fmt;
    
    // 打开文件的缓冲区输入输出，flags 标识为  AVIO_FLAG_READ_WRITE ，可读写
    if (avio_open(&pFormatCtx->pb, out_file, AVIO_FLAG_READ_WRITE) < 0){
        printf("Failed to open output file! \n");
        return -1;
    }
    
    // 创建新的输出流, 用于写入文件
    video_stream = avformat_new_stream(pFormatCtx, 0);
    
    // 设置帧率
    video_stream->time_base.num = 1;
    video_stream->time_base.den = 30;
    if (video_stream==NULL){
        return -1;
    }
    
    // 从媒体流中获取到编码结构体，他们是一一对应的关系，一个 AVStream 对应一个  AVCodecContext
    pCodecCtx = video_stream->codec;
    
    // 设置编码器的编码格式(是一个id)，每一个编码器都对应着自己的 id，例如 h264 的编码 id 就是 AV_CODEC_ID_H264
    pCodecCtx->codec_id = out_fmt->video_codec;
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P; // AV_PIX_FMT_YUV420P
    pCodecCtx->width = encoder_h264_frame_width;
    pCodecCtx->height = encoder_h264_frame_height;
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = 30;
    pCodecCtx->bit_rate = bitrate;
    
    // 视频质量度量标准(常见qmin=10, qmax=51)
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;
    
//    // 设置图像组层的大小(GOP-->两个I帧之间的间隔)
//    pCodecCtx->gop_size = 30;
//
//    // 设置 B 帧最大的数量，B帧为视频图片空间的前后预测帧， B 帧相对于 I、P 帧来说，压缩率比较大，也就是说相同码率的情况下，
//    // 越多 B 帧的视频，越清晰，现在很多打视频网站的高清视频，就是采用多编码 B 帧去提高清晰度，
//    // 但同时对于编解码的复杂度比较高，比较消耗性能与时间
//    pCodecCtx->max_b_frames = 5;
//
//    // 可选设置
    AVDictionary *param = 0;
    // H.264
    if(pCodecCtx->codec_id == AV_CODEC_ID_H264) {
        // 通过--preset的参数调节编码速度和质量的平衡。
        av_dict_set(&param, "preset", "slow", 0);

        // 通过--tune的参数值指定片子的类型，是和视觉优化的参数，或有特别的情况。
        // zerolatency: 零延迟，用在需要非常低的延迟的情况下，比如视频直播的编码
        av_dict_set(&param, "tune", "zerolatency", 0);
    }
    
    // 输出打印信息，内部是通过printf函数输出（不需要输出可以注释掉该局）
//    av_dump_format(pFormatCtx, 0, out_file, 1);
    
    // 通过 codec_id 找到对应的编码器
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec) {
        printf("Can not find encoder! \n");
        return -1;
    }
    
    // 打开编码器，并设置参数 param
    if (avcodec_open2(pCodecCtx, pCodec,&param) < 0) {
        printf("Failed to open encoder! \n");
        return -1;
    }
    
    // 初始化原始数据对象: AVFrame
    pFrame = av_frame_alloc();
    
    // 通过像素格式(这里为 YUV)获取图片的真实大小，例如将 1080 * 1920 转换成 int 类型
    avpicture_fill((AVPicture *)pFrame, picture_buf, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    
    // h264 封装格式的文件头部，基本上每种编码都有着自己的格式的头部，想看具体实现的同学可以看看 h264 的具体实现
    avformat_write_header(pFormatCtx, NULL);
    
    // 创建编码后的数据 AVPacket 结构体来存储 AVFrame 编码后生成的数据
    av_new_packet(&pkt, picture_size);
    
    return 0;
}

/*
 * 将CMSampleBufferRef格式的数据编码成h264并写入文件
 *
 */
- (void)encoderToH264:(CMSampleBufferRef)sampleBuffer
{
    // 通过CMSampleBufferRef对象获取CVPixelBufferRef对象
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 锁定imageBuffer内存地址开始进行编码
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess) {
        // 3.从CVPixelBufferRef读取YUV的值
        UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
        UInt8 *bufferPtr1 = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);
        
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        size_t bytesrow0 = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
        size_t bytesrow1  = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,1);
        UInt8 *yuv420_data = (UInt8 *)malloc(width * height *3/2);
        
        UInt8 *pY = bufferPtr ;
        UInt8 *pUV = bufferPtr1;
        UInt8 *pU = yuv420_data + width*height;
        UInt8 *pV = pU + width*height/4;
        for(int i =0;i<height;i++)
        {
            memcpy(yuv420_data+i*width,pY+i*bytesrow0,width);
        }
        for(int j = 0;j<height/2;j++)
        {
            for(int i =0;i<width/2;i++)
            {
                *(pU++) = pUV[i<<1];
                *(pV++) = pUV[(i<<1) + 1];
            }
            pUV+=bytesrow1;
        }
        
        
        
        // 分别读取YUV的数据
        picture_buf = yuv420_data;
        y_size = pCodecCtx->width * pCodecCtx->height;
        pFrame->data[0] = picture_buf;              // Y
        pFrame->data[1] = picture_buf+ y_size;      // U
        pFrame->data[2] = picture_buf+ y_size*5/4;  // V
        
        // 4.设置当前帧
        pFrame->pts = framecnt;
        int got_picture = 0;
        
        // 4.设置宽度高度以及YUV各式
        pFrame->width = encoder_h264_frame_width;
        pFrame->height = encoder_h264_frame_height;
        pFrame->format = AV_PIX_FMT_YUV420P;
        
        // 对编码前的原始数据(AVFormat)利用编码器进行编码，将 pFrame 编码后的数据传入pkt 中
        int ret = avcodec_encode_video2(pCodecCtx, &pkt, pFrame, &got_picture);
        if(ret < 0) {
            printf("Failed to encode! \n");
        }else if (ret == 0){
            if (pkt.buf) {
                printf("encode success, data length: %d \n",pkt.buf->size);
            }
            
        }
        
        // 编码成功后写入 AVPacket 到output文件中
        if (got_picture == 1) {  // 说明不为空，此时把数据写到输出文件中
            framecnt++;
            pkt.stream_index = video_stream->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            
            av_free_packet(&pkt);
        }
        free(yuv420_data);
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

/*
 * 释放资源
 */
- (void)freeH264Resource
{
    // 1.释放AVFormatContext
    int ret = flush_encoder(pFormatCtx,0);
    if (ret < 0) {
        printf("Flushing encoder failed\n");
    }
    
    // 将还未输出的AVPacket输出出来
    av_write_trailer(pFormatCtx);
    
    // 关闭资源
    if (video_stream){
        avcodec_close(video_stream->codec);
        av_free(pFrame);
    }
    avio_close(pFormatCtx->pb);
    avformat_free_context(pFormatCtx);
}

int flush_encoder(AVFormatContext *fmt_ctx,unsigned int stream_index)
{
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
          CODEC_CAP_DELAY))
        return 0;
    
    while (1) {
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_video2 (fmt_ctx->streams[stream_index]->codec, &enc_pkt,
                                     NULL, &got_frame);
        av_frame_free(NULL);
        if (ret < 0)
            break;
        if (!got_frame){
            ret=0;
            break;
        }
        ret = av_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0)
            break;
    }
    return ret;
}


@end
