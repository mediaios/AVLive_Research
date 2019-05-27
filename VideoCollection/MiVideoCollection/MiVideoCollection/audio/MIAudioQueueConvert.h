//
//  MIAudioQueueConvert.h
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/20.
//  Copyright © 2019年 iosmediadev@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIAudioQueueConvert : NSObject

@property (nonatomic,assign) BOOL m_isRunning;
- (void)stopRecorder;
- (void)startRecorder;

- (void)convertPCMToAAC:(MIAudioQueueConvert *)convert;

@end

NS_ASSUME_NONNULL_END
