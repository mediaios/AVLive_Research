//
//  MIAudioCollectionVC.m
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/15.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIAudioCollectionVC.h"
#import "MIAudioQueueRecord.h"
#import "MIAudioUnit.h"
#import "MIAudioQueuePlay.h"
#import "MIAudioQueueConvert.h"

@interface MIAudioCollectionVC ()
@property (nonatomic,strong) MIAudioQueueRecord *miAQ;
@property (nonatomic,strong) MIAudioUnit *miAUnit;

@property (nonatomic,strong) MIAudioQueuePlay *aqPlay;
@property (nonatomic,strong) MIAudioQueueConvert *queueConvert;
@end

@implementation MIAudioCollectionVC

- (MIAudioQueueRecord *)miAQ
{
    if (!_miAQ) {
        _miAQ = [[MIAudioQueueRecord alloc] init];
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

- (MIAudioQueuePlay *)aqPlay
{
    if (!_aqPlay) {
        _aqPlay = [[MIAudioQueuePlay alloc] init];
    }
    return _aqPlay;
}

- (MIAudioQueueConvert *)queueConvert
{
    if (!_queueConvert) {
        _queueConvert = [[MIAudioQueueConvert alloc] init];
    }
    return _queueConvert;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

#pragma mark -AudioQueue的操作

- (IBAction)onPressedBtnQueueRecord:(id)sender {
    [self.miAQ startRecorder];
}

- (IBAction)onPressedBtnQueuePlay:(id)sender {
    [self.aqPlay startPlay];
}

- (IBAction)onPressedBtnQueueConvert:(id)sender {
    [self.queueConvert startRecorder];
}


#pragma mark -AudioUnit的操作

- (IBAction)onPressedBtnUnitRecord:(id)sender {
    [self.miAUnit startAudioUnitRecorder];
}

- (IBAction)onPressedBtnUnitPlay:(id)sender {
    
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
