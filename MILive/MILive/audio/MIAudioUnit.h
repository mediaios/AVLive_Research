//
//  MIAudioUnit.h
//  MILive
//
//  Created by mediaios on 2019/5/16.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIAudioUnit : NSObject
{
    
    AudioStreamBasicDescription     dataFormat;
    
@public
    AudioUnit                       m_audioUnit;
    AudioBufferList                 *m_audioBufferList;
}

@property (nonatomic,assign) BOOL m_isRunning;

//+ (instancetype)shareInstance;
- (void)startAudioUnitRecorder;  // start recorder
- (void)stopAudioUnitRecorder;   // stop recorder

@end

NS_ASSUME_NONNULL_END
