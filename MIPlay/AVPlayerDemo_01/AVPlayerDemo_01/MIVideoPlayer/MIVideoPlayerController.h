//
//  MIVideoPlayerController.h
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/15.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIVideoPlayerController : NSObject


/**
 @brief 播放网络视频文件

 @param url 网络视频文件地址
 @param view 视频要被显示在哪个view上面
 */
- (void)playUrl:(NSString *)url onView:(UIView *)view;


/**
 @brief 播放本地视频文件

 @param path 视频文件地址
 @param view 视频要被显示在哪个view上面
 */
- (void)playLocalPath:(NSString *)path onView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
