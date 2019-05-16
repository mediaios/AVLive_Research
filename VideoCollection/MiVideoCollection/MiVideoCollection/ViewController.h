//
//  ViewController.h
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/11.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController
{
    @public
    AudioUnit        miIoUnitInstance;
    AudioBufferList  *audioBufferList;
}

- (void)stop;
@end

