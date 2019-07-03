# AVLive_Research
ios音视频直播及播放技术预研总结


## 采集 

### 视频采集 

* [介绍在ios设备上如何进行视频采集](https://juejin.im/post/5cdaee84e51d453a506b0f0f)


### 音频采集 

* [音频基础知识](https://juejin.im/post/5ced12e6f265da1b5d578bb5)
* [Audio Queue Services Programming Guide](https://juejin.im/post/5cdb8a88518825123570f4f3)
* [利用AudioQueue做音频采集编码和播放](https://juejin.im/post/5ced1568f265da1b6f4355b9)
* audio unit

## 编码 

### 视频编码

* [视频的基本参数及H264编解码相关概念](https://juejin.im/post/5cf07dfdf265da1b8466ca8c)
* [视频H264硬编码和软编码&编译ffmpeg库及环境搭建](https://juejin.im/post/5cf0cf63f265da1bc64ba8e0)

* H265编码
* H265硬编码
* H265软编码(ffmpeg)

### 音频编码 

* [对音频的介绍以及音频格式介绍](https://juejin.im/post/5ced12e6f265da1b5d578bb5)
* [利用`AudioToolBox`把音频PCM转化为AAC](https://juejin.im/post/5ced1568f265da1b6f4355b9)
* 利用FFMPEG把PCM转化成AAC

## 对音视频做MUX 

* 把音频AAC和视频H264转化ASF文件
* 把ASF文件转化成MP4文件
* 把音频AAC和视频H264转化成其它格式的文件

## 推流 

* [在mac和centos服务器上搭建一个ngix，被用于做RTMP推流](https://juejin.im/post/5d1c1f2c6fb9a07ecb0bc32f)
* [直播简单实现——利用librtm推流](https://juejin.im/post/5d1c1f2c6fb9a07ecb0bc32f)
* 利用ffmpeg推流到rtmp服务

## 阶段成果
利用上面的知识点做一个推流SDK 


## 音视频播放 

### OPenGL2的学习 
  * 关于OPenGL
  * 关于定点着色器和片源着色器




