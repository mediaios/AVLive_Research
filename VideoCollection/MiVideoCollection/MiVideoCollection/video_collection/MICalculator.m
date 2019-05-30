//
//  MICalculator.m
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/12.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MICalculator.h"
#import <CoreMedia/CoreMedia.h>

@implementation MICalculator

/**
 *  calculate capture video FPS
 */
static int captureVideoFPS;
+ (void)calculatorCaptureFPS
{
    static int count = 0;
    static float lastTime = 0;
    CMClockRef hostClockRef = CMClockGetHostTimeClock();
    CMTime hostTime = CMClockGetTime(hostClockRef);
    float nowTime = CMTimeGetSeconds(hostTime);
    if(nowTime - lastTime >= 1)
    {
        captureVideoFPS = count;
        lastTime = nowTime;
        count = 0;
    }
    else
    {
        count ++;
    }
}

+ (int)getCaptureVideoFPS
{
    return captureVideoFPS;
}

@end
