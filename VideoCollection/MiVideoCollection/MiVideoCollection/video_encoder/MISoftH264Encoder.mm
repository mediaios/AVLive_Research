//
//  MISoftH264Encoder.m
//  MiVideoCollection
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

- (int)setX264ResourceWithVideoWidth:(int)width height:(int)height bitrate:(int)bitrate
{
    // 1.默认从第0帧开始(记录当前的帧数)
    framecnt = 0;
    
    // 2.记录传入的宽度&高度
    encoder_h264_frame_width = width;
    encoder_h264_frame_height = height;
    
    // 3.注册FFmpeg所有编解码器(无论编码还是解码都需要该步骤)
    av_register_all();
    
    // 4.初始化AVFormatContext: 用作之后写入视频帧并编码成 h264，贯穿整个工程当中(释放资源时需要销毁)
    pFormatCtx = avformat_alloc_context();
    
    // 5.设置输出文件的路径
    out_fmt = av_guess_format(NULL, out_file, NULL);
    pFormatCtx->oformat = out_fmt;
    
    // 6.打开文件的缓冲区输入输出，flags 标识为  AVIO_FLAG_READ_WRITE ，可读写
    if (avio_open(&pFormatCtx->pb, out_file, AVIO_FLAG_READ_WRITE) < 0){
        printf("Failed to open output file! \n");
        return -1;
    }
    
    // 7.创建新的输出流, 用于写入文件
    video_stream = avformat_new_stream(pFormatCtx, 0);
    
    // 8.设置 30 帧每秒 ，也就是 fps 为 30
    video_stream->time_base.num = 1;
    video_stream->time_base.den = 30;
    
    if (video_stream==NULL){
        return -1;
    }
    
    // 9.pCodecCtx 用户存储编码所需的参数格式等等
    // 9.1.从媒体流中获取到编码结构体，他们是一一对应的关系，一个 AVStream 对应一个  AVCodecContext
    pCodecCtx = video_stream->codec;
    
    // 9.2.设置编码器的编码格式(是一个id)，每一个编码器都对应着自己的 id，例如 h264 的编码 id 就是 AV_CODEC_ID_H264
    pCodecCtx->codec_id = out_fmt->video_codec;
    
    // 9.3.设置编码类型为 视频编码
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    
    // 9.4.设置像素格式为 yuv 格式
    pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P; // AV_PIX_FMT_YUV420P
    
    // 9.5.设置视频的宽高
    pCodecCtx->width = encoder_h264_frame_width;
    pCodecCtx->height = encoder_h264_frame_height;
    
    // 9.6.设置帧率
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = 30;
    
    // 9.7.设置码率（比特率）
    pCodecCtx->bit_rate = bitrate;
    
    // 9.8.视频质量度量标准(常见qmin=10, qmax=51)
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;
    
    // 9.9.设置图像组层的大小(GOP-->两个I帧之间的间隔)
    pCodecCtx->gop_size = 30;
    
    // 9.10.设置 B 帧最大的数量，B帧为视频图片空间的前后预测帧， B 帧相对于 I、P 帧来说，压缩率比较大，也就是说相同码率的情况下，
    // 越多 B 帧的视频，越清晰，现在很多打视频网站的高清视频，就是采用多编码 B 帧去提高清晰度，
    // 但同时对于编解码的复杂度比较高，比较消耗性能与时间
    pCodecCtx->max_b_frames = 5;
    
    // 10.可选设置
    AVDictionary *param = 0;
    // H.264
    if(pCodecCtx->codec_id == AV_CODEC_ID_H264) {
        // 通过--preset的参数调节编码速度和质量的平衡。
        av_dict_set(&param, "preset", "slow", 0);
        
        // 通过--tune的参数值指定片子的类型，是和视觉优化的参数，或有特别的情况。
        // zerolatency: 零延迟，用在需要非常低的延迟的情况下，比如视频直播的编码
        av_dict_set(&param, "tune", "zerolatency", 0);
    }
    
    // 11.输出打印信息，内部是通过printf函数输出（不需要输出可以注释掉该局）
//    av_dump_format(pFormatCtx, 0, out_file, 1);
    
    // 12.通过 codec_id 找到对应的编码器
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec) {
        printf("Can not find encoder! \n");
        return -1;
    }
    
    // 13.打开编码器，并设置参数 param
    if (avcodec_open2(pCodecCtx, pCodec,&param) < 0) {
        printf("Failed to open encoder! \n");
        return -1;
    }
    
    // 13.初始化原始数据对象: AVFrame
    pFrame = av_frame_alloc();
    
    // 14.通过像素格式(这里为 YUV)获取图片的真实大小，例如将 480 * 720 转换成 int 类型
    avpicture_fill((AVPicture *)pFrame, picture_buf, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    
    // 15.h264 封装格式的文件头部，基本上每种编码都有着自己的格式的头部，想看具体实现的同学可以看看 h264 的具体实现
    avformat_write_header(pFormatCtx, NULL);
    
    // 16.创建编码后的数据 AVPacket 结构体来存储 AVFrame 编码后生成的数据
    av_new_packet(&pkt, picture_size);
    
    // 17.设置 yuv 数据中 y 图的宽高
    y_size = pCodecCtx->width * pCodecCtx->height;
    
    return 0;
}

/*
 * 将CMSampleBufferRef格式的数据编码成h264并写入文件
 *
 */
- (void)encoderToH264:(CMSampleBufferRef)sampleBuffer
{
    // 1.通过CMSampleBufferRef对象获取CVPixelBufferRef对象
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 2.锁定imageBuffer内存地址开始进行编码
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess) {
        // 3.从CVPixelBufferRef读取YUV的值
        // NV12和NV21属于YUV格式，是一种two-plane模式，即Y和UV分为两个Plane，但是UV（CbCr）为交错存储，而不是分为三个plane
        // 3.1.获取Y分量的地址
        UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
        // 3.2.获取UV分量的地址
        UInt8 *bufferPtr1 = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);
        
        // 3.3.根据像素获取图片的真实宽度&高度
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        // 获取Y分量长度
        size_t bytesrow0 = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
        size_t bytesrow1  = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,1);
        UInt8 *yuv420_data = (UInt8 *)malloc(width * height *3/2);
        
        // 3.4.将NV12数据转成YUV420P(I420)数据
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
        
        // 3.5.分别读取YUV的数据
        picture_buf = yuv420_data;
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
        
        // 5.对编码前的原始数据(AVFormat)利用编码器进行编码，将 pFrame 编码后的数据传入pkt 中
        int ret = avcodec_encode_video2(pCodecCtx, &pkt, pFrame, &got_picture);
        if(ret < 0) {
            printf("Failed to encode! \n");
        }else if (ret == 0){
            if (pkt.buf) {
                printf("encode success, data length: %d \n",pkt.buf->size);
            }
            
        }
        
        // 6.编码成功后写入 AVPacket 到 输入输出数据操作着 pFormatCtx 中，当然，记得释放内存
        if (got_picture==1) {
            framecnt++;
            pkt.stream_index = video_stream->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            
            av_free_packet(&pkt);
        }
        
        // 7.释放yuv数据
        free(yuv420_data);
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

/*
 * 释放资源
 */
- (void)freeX264Resource
{
    // 1.释放AVFormatContext
    int ret = flush_encoder(pFormatCtx,0);
    if (ret < 0) {
        printf("Flushing encoder failed\n");
    }
    
    // 2.将还未输出的AVPacket输出出来
    av_write_trailer(pFormatCtx);
    
    // 3.关闭资源
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
