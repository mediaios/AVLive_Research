//
//  MIConst.h
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/16.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#ifndef MIConst_h
#define MIConst_h


/*** for audio queue ***/
#define kAudioSampleRate            48000
#define kAudioFramesPerPacket       1
#define kAudioPCMTotalPacket        512
#define kAudioBytesPerPacket        2
#define kQueueBuffers 3  // 输出音频队列缓冲个数

/** Audio recorder **/
#define kAudioQueueRecorderSampleRate               48000
#define kAudioQueueRecorderPCMFramesPerPacket       1
#define kAudioQueueRecorderPCMTotalPacket           512
#define kAudioQueueRecorderAudioBytesPerPacket       2

#define kAudioRecoderPCMMaxBuffSize                 2048



#define kNumberQueueBuffers 3


#endif /* MIConst_h */
