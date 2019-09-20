//
//  MIVideoPlayer.h
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/15.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MIVideoPlayerDef.h"

NS_ASSUME_NONNULL_BEGIN

@class MIVideoPlayer;
@protocol MIVideoPlayerDelegate <NSObject>

- (void)videoPlayer:(MIVideoPlayer *)videoPlayer
   videoPlayerState:(MIVideoPlayerState)state;

- (void)videoPlayer:(MIVideoPlayer *)videoPlayer
          totalTime:(NSUInteger)totalTime
        currentTime:(NSUInteger)currentTime;

- (void)videoPlayer:(MIVideoPlayer *)videoPlayer
     bufferProgress:(CGFloat)buffProgress;
@end



@interface MIVideoPlayer : NSObject

@property (nonatomic,weak) id<MIVideoPlayerDelegate> delegate;
@property (nonatomic, assign) CGSize videoSize;

/**
 @brief 在视频播放完成时是否需要重播，默认是NO
 */
@property (nonatomic,assign) BOOL enableReplay;

/**
 @brief 开始播放视频
 */
- (void)play;

/**
 @brief 暂停播放
 */
- (void)pause;

/**
 @brief 停止并销毁播放器
 */
- (void)destoryPlayer;

/**
 @brief 从指定时间点开始播放

 @param fromTime 指定的时间点
 */
- (void)seekPlayFromTime:(float)fromTime;

/**
 @brief 播放视频

 @param url 视频url
 @param videoView 视频显示视图
 */
- (void)playUrl:(NSString *)url onView:(UIView *)videoView;


/**
 @brief 播放本地文件

 @param path 本地文件路径
 @param videoView 视频显示视图
 */
- (void)playLocalFile:(NSString *)path onView:(UIView *)videoView;

/**
 @brief 设置显示层位置尺寸

 @param frame 显示层的frame
 */
- (void)settingFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END
