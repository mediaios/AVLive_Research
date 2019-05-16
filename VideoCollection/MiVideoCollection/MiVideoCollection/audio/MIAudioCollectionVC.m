//
//  MIAudioCollectionVC.m
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/15.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIAudioCollectionVC.h"
#import "MIAudioQueue.h"

@interface MIAudioCollectionVC ()
@property (nonatomic,strong) MIAudioQueue *miAQ;
@end

@implementation MIAudioCollectionVC

- (MIAudioQueue *)miAQ
{
    if (!_miAQ) {
        _miAQ = [[MIAudioQueue alloc] init];
    }
    return _miAQ;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.miAQ startRecorder];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.miAQ stopRecorder];
}

- (IBAction)onPressedBtnDismiss:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
