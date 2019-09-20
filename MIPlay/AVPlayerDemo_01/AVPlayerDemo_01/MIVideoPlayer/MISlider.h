//
//  MISlider.h
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/22.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MISlider : UIControl


#pragma mark- public propertys
/**
 @brief 播放进度
 */
@property (nonatomic, assign) CGFloat playProgress;

/**
 @brief 缓冲进度
 */
@property (nonatomic, assign) CGFloat bufferProgress;


#pragma mark- public methods

- (void)setupColorWithTrackColor:(UIColor *)trackColor
                  bufferedCollor:(UIColor *)bufferedCollor
                     playedColor:(UIColor *)playedColor;

/** 可为滑块设置图片 */
- (void)setDotImage:(UIImage *)dotImage forState:(UIControlState)state;

//横竖屏转换
- (void)beginFullScreen:(BOOL)isFullScreen;
@end

NS_ASSUME_NONNULL_END
