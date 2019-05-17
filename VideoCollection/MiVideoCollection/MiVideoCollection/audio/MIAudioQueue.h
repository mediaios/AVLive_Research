//
//  MIAudioQueue.h
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/15.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIAudioQueue : NSObject

@property (nonatomic,assign) BOOL m_isRunning;
- (void)stopRecorder;
- (void)startRecorder;

@end

NS_ASSUME_NONNULL_END
