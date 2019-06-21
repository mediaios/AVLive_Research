//
//  MICalculator.h
//  MILive
//
//  Created by mediaios on 2019/5/12.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MICalculator : NSObject


/**
 calculate capture video FPS
 */
+ (void)calculatorCaptureFPS;

/**
 Get capture video FPS

 @return capture video FPS
 */
+ (int)getCaptureVideoFPS;

@end

NS_ASSUME_NONNULL_END
