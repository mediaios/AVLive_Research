//
//  MIVideoPlayerDef.h
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/15.
//  Copyright © 2019 mediaios. All rights reserved.
//

#ifndef MIVideoPlayerDef_h
#define MIVideoPlayerDef_h


typedef NS_ENUM(NSUInteger, MIVideoPlayerState)
{
    MIVideoPlayerState_StartBuffer,
    MIVideoPlayerState_EndBuffer,
    MIVideoPlayerState_DidPlay,
    MIVideoPlayerState_DidPause,
    MIVideoPlayerState_EndPlay
};


typedef NS_ENUM(NSUInteger, MIVideoPlayerPaneEvent)
{
    MIVideoPlayerPaneEvent_Back,
    MIVideoPlayerPaneEvent_FullScreen,
    MIVideoPlayerPaneEvent_Play,
    MIVideoPlayerPaneEvent_Pause
};


#endif /* MIVideoPlayerDef_h */
