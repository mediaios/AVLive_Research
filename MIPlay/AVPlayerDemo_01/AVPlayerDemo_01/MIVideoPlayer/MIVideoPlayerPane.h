//
//  MIVideoPlayerPane.h
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/15.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MIVideoPlayerDef.h"

NS_ASSUME_NONNULL_BEGIN

@class MIVideoPlayerPane;
@protocol MIVideoPlayerPaneDelegate <NSObject>

- (void)videoPlayerPane:(MIVideoPlayerPane *)videoPlayerPane
   videoPlayerPaneEvent:(MIVideoPlayerPaneEvent)paneEvent;


- (void)videoPlayerPane:(MIVideoPlayerPane*)videoPlayerPane
          didPlayToTime:(CGFloat)time;
@end

@interface MIVideoPlayerPane : UIView
@property (nonatomic,weak) id<MIVideoPlayerPaneDelegate> delegate;

@property (nonatomic,assign) NSUInteger currentTime;
@property (nonatomic,assign) NSUInteger totalTime;
@property (nonatomic, assign) CGFloat  playValue;   //播放进度
@property (nonatomic, assign) CGFloat  progress;    //缓冲进度

//@property (nonatomic,assign) MIPaneLayoutType paneLayoutType;

//播放器调用方法
- (void)videoPlayerDidLoading;

- (void)videoPlayerDidBeginPlay;

- (void)videoPlayerDidEndPlay;

- (void)videoPlayerDidFailedPlay;

- (void)playerPanePlay;
- (void)playerPanePause;

- (void)fullScreenChanged:(BOOL)isFullScreen frame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END
