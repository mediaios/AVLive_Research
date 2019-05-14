# AVLive_Research
ios音视频直播及播放技术预研总结


## 采集 

### 视频采集 

* [介绍在ios设备上如何进行视频采集](https://juejin.im/post/5cdaee84e51d453a506b0f0f)


### 音频采集 

* 对音频的格式及参数做介绍
* audio queue
* audio unit 

## 编码 

### 视频编码

* H264编码 
* H264硬编码 
* H264软编码(ffmpeg)
 * 如何在mac上编译出ffmpeg库
 * 对ffmpeg做一个简单的介绍

* H265编码
* H265硬编码
* H265软编码(ffmpeg)

### 音频编码 

* 对音频的介绍以及音频格式介绍
* 利用`AudioToolBox`把音频PCM转化为AAC
* 利用FFMPEG把PCM转化成AAC

## 对音视频做MUX 

* 把音频AAC和视频H264转化ASF文件
* 把ASF文件转化成MP4文件
* 把音频AAC和视频H264转化成其它格式的文件

## 推流 

* 在mac上搭建一个ngix，被用于做RTMP推流
* 利用ffmpeg推流到rtmp服务 

## 阶段成果
利用上面的知识点做一个推流SDK 


## 音视频播放 

### OPenGL2的学习 
  * 关于OPenGL
  * 关于定点着色器和片源着色器




