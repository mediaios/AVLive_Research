//
//  ViewController.m
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/14.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import "ViewController.h"
#import "MIVideoPlayer.h"
#import "MIVideoPlayerController.h"

@interface ViewController()
@property (nonatomic ,strong) UIView *videoPlayBGView;
@property (nonatomic,strong) MIVideoPlayer *vPlayer;
@property (nonatomic,strong) MIVideoPlayerController *vPlaying;
@end


@implementation ViewController


-(MIVideoPlayerController *)vPlaying
{
    if (!_vPlaying) {
        _vPlaying = [[MIVideoPlayerController alloc] init];
    }
    return _vPlaying;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.videoPlayBGView = [[UIView alloc] initWithFrame:CGRectMake(0, 44, self.view.frame.size.width, self.view.frame.size.width * 0.6)];
    self.videoPlayBGView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.videoPlayBGView];
}

- (IBAction)playNetVideo:(id)sender {
    [self.vPlaying playUrl:@"http://pw80er50j.bkt.clouddn.com/videoplayback.mp4" onView:self.videoPlayBGView];
}

- (IBAction)playLocalVideo:(id)sender {
    NSString *urlStr = [[NSBundle mainBundle] pathForResource:@"xxsj" ofType:@"mp4"];
    [self.vPlaying playLocalPath:urlStr onView:self.videoPlayBGView];
}

@end
