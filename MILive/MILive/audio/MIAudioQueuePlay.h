//
//  MIAudioQueuePlay.h
//  MILive
//
//  Created by mediaios on 2019/5/17.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIAudioQueuePlay : NSObject
- (void)startPlay;
-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB;
@end

NS_ASSUME_NONNULL_END
