//
//  MIAudioCollectionVC.m
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/15.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIAudioCollectionVC.h"
#import "MIAudioQueue.h"
#import "MIAudioUnit.h"

@interface MIAudioCollectionVC ()
@property (nonatomic,strong) MIAudioQueue *miAQ;
@property (nonatomic,strong) MIAudioUnit *miAUnit;
@end

@implementation MIAudioCollectionVC

- (MIAudioQueue *)miAQ
{
    if (!_miAQ) {
        _miAQ = [[MIAudioQueue alloc] init];
    }
    return _miAQ;
}

- (MIAudioUnit *)miAUnit
{
    if (!_miAUnit) {
        _miAUnit = [[MIAudioUnit alloc] init];
    }
    return _miAUnit;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
//    [self.miAQ startRecorder];
    
    [self.miAUnit startAudioUnitRecorder];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
//    [self.miAQ stopRecorder];
    
    [self.miAUnit stopAudioUnitRecorder];
}

- (IBAction)onPressedBtnDismiss:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
