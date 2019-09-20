//
//  MIVideoPlayerHelper.m
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/22.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import "MIVideoPlayerHelper.h"

const CGFloat PI = 3.1415926;

@implementation MIVideoPlayerHelper

+ (UIImage *)generateImageWithColor:(UIColor *)color radius:(CGFloat)radius
{
    CGRect rect = CGRectMake(0.0f, 0.0f,radius * 2 + 4, radius * 2 + 4);
    
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
    CGContextRef context =UIGraphicsGetCurrentContext();
    CGContextSetRGBStrokeColor(context,1,1,1,1.0);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 4.0);
    CGContextAddArc(context, radius + 2,radius + 2, radius, 0, 2*PI, 0);
    CGContextDrawPath(context, kCGPathFillStroke);
    UIImage *myImage =UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return myImage;
}

+ (UIImage*)generateImageWithView:(UIView *)view
{
    CGRect rect = view.frame;
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [view.layer renderInContext:context];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
