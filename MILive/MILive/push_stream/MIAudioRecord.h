//
//  MIAudioQueueConvert.h
//  MILive
//
//  Created by mediaios on 2019/5/20.
//  Copyright © 2019年 iosmediadev@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class MIAudioRecord;

@protocol MIAudioEncoderDelegate <NSObject>
- (void)audioEncoder:(MIAudioRecord *)encoder audioHeader:(NSData *)audioH;
- (void)audioEncoder:(MIAudioRecord *)encoder audioData:(NSData *)audioData;

@end


@interface MIAudioRecord : NSObject

@property (nonatomic,weak) id<MIAudioEncoderDelegate> delegate;
@property (nonatomic,assign) BOOL m_isRunning;
- (void)stopRecorder;
- (void)startRecorder;

- (void)encodePCMToAAC:(MIAudioRecord *)convert;
- (size_t)copyPCMSamplesIntoBuffer:(AudioBufferList*)ioData;

@end

NS_ASSUME_NONNULL_END
