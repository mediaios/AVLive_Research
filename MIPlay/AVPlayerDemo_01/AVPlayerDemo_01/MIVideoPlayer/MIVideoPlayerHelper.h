//
//  MIVideoPlayerHelper.h
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/22.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MIVideoPlayerHelper : NSObject

/** 根据颜色和圆的半径来创建一个 Image */

/**
 @brief 创建一个圆形image

 @param color image的颜色
 @param radius 圆形image的半径
 @return 返回一个圆形image
 */
+ (UIImage *)generateImageWithColor:(UIColor *)color radius:(CGFloat)radius;

/**
 @brief 转换一个UIView成UIImage
 
 @param view 要被转化为UIImage的UIView
 @return 返回转换好的UIImage
 */
+ (UIImage*)generateImageWithView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
