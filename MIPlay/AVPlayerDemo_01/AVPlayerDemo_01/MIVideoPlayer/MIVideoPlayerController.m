//
//  MIVideoPlayerController.m
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/15.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import "MIVideoPlayerController.h"
#import "MIVideoPlayerPane.h"
#import "MIVideoPlayer.h"

@interface MIVideoPlayerController()<MIVideoPlayerDelegate,MIVideoPlayerPaneDelegate>

@property (nonatomic, strong) UIView *backgroundView;
///用于视频显示的View
@property (nonatomic, strong) UIView *videoShowView;
@property (nonatomic,strong) MIVideoPlayerPane *videoPane;
@property (nonatomic,strong) MIVideoPlayer *videoPlayer;
@property (nonatomic, assign) CGRect originFrame;
@property (nonatomic,assign) BOOL isFullScreen;

@end


@implementation MIVideoPlayerController

- (MIVideoPlayer *)videoPlayer{
    if (!_videoPlayer) {
        _videoPlayer = [[MIVideoPlayer alloc] init];
        _videoPlayer.delegate = self;
    }
    return _videoPlayer;
}

- (UIView *)videoShowView{
    if (!_videoShowView) {
        _videoShowView = [[UIView alloc] initWithFrame:self.backgroundView.bounds];
        [self.backgroundView addSubview:_videoShowView];
    }
    return _videoShowView;
}

- (MIVideoPlayerPane *)videoPane
{
    if (!_videoPane) {
        _videoPane = [[MIVideoPlayerPane alloc]
                      initWithFrame:self.backgroundView.bounds];
        _videoPane.delegate = self;
        [self.backgroundView addSubview:_videoPane];
    }
    return _videoPane;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addObserver];
    }
    return self;
}
- (void)dealloc
{
    [self removeObserver];
}

- (void)rotateDevice
{
    UIDeviceOrientation orientation;
    if (_isFullScreen) {
        orientation = UIDeviceOrientationLandscapeLeft;
    }else{
        orientation = UIDeviceOrientationPortrait;
    }
    [UIView animateWithDuration:0.25 animations:^{
        [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:orientation] forKey:@"orientation"];
        [self settingSubViewFrames];
    }];
}

- (void)settingSubViewFrames
{
    CGRect frame;
    if (_isFullScreen) {
        frame = [UIScreen mainScreen].bounds;
    }else{
        frame = _originFrame;
    }
    self.backgroundView.frame = frame;
    [_videoPlayer settingFrame:self.backgroundView.bounds];
    [_videoPane fullScreenChanged:_isFullScreen frame:self.backgroundView.bounds];
}

#pragma mark- MIVideoPlayerDelegate
- (void)videoPlayer:(MIVideoPlayer *)videoPlayer
          totalTime:(NSUInteger)totalTime
        currentTime:(NSUInteger)currentTime
{
    if (totalTime > 0) {
        _videoPane.totalTime = totalTime;
    }
    
    if (currentTime > 0 && _videoPane.totalTime > 0) {
        _videoPane.currentTime = currentTime;
        _videoPane.playValue = (CGFloat)_videoPane.currentTime/(CGFloat)_videoPane.totalTime;
    }
    
}

- (void)videoPlayer:(MIVideoPlayer *)videoPlayer bufferProgress:(CGFloat)buffProgress
{
    _videoPane.progress = buffProgress;
}

- (void)videoPlayer:(MIVideoPlayer *)videoPlayer
   videoPlayerState:(MIVideoPlayerState)state
{
    switch (state) {
        case MIVideoPlayerState_DidPlay:
            {
                [_videoPane playerPanePlay];
                [_videoPane videoPlayerDidBeginPlay];
            }
            break;
        case MIVideoPlayerState_DidPause:
        {
            [_videoPane playerPanePause];
        }
            break;
        case MIVideoPlayerState_EndBuffer:
        {
            
        }
            break;
        case MIVideoPlayerState_StartBuffer:
        {
            [_videoPane videoPlayerDidLoading];
        }
            break;
            
        default:
            break;
    }
}

#pragma mark-MIVideoPlayerPaneDelegate
- (void)videoPlayerPane:(MIVideoPlayerPane *)videoPlayerPane videoPlayerPaneEvent:(MIVideoPlayerPaneEvent)paneEvent
{
    switch (paneEvent) {
        case MIVideoPlayerPaneEvent_Pause:
            {
                [_videoPlayer pause];
            }
            break;
        case MIVideoPlayerPaneEvent_Play:
        {
            [_videoPlayer play];
        }
            break;
        case MIVideoPlayerPaneEvent_Back:
        {
            if (_isFullScreen) {
                _isFullScreen = !_isFullScreen;
                [self rotateDevice];
            }else{
                [_videoPlayer destoryPlayer];
            }
        }
            break;
        case MIVideoPlayerPaneEvent_FullScreen:
        {
            _isFullScreen = !_isFullScreen;
            [self rotateDevice];
        }
            break;
            
        default:
            break;
    }
}

- (void)videoPlayerPane:(MIVideoPlayerPane*)videoPlayerPane didPlayToTime:(CGFloat)time
{
    [_videoPlayer seekPlayFromTime:time];
}


- (void)playUrl:(NSString *)url onView:(UIView *)view
{
    if (self.videoPlayer) {
        _videoPlayer = nil;
    }
    
    self.backgroundView = view;
    self.originFrame = view.frame;
    
    [self.videoPlayer playUrl:url onView:self.videoShowView];
    [self videoPane];
}

- (void)playLocalPath:(NSString *)path onView:(UIView *)view
{
    if (self.videoPlayer) {
        _videoPlayer = nil;
    }
    self.backgroundView = view;
    self.originFrame = view.frame;
    
    [self.videoPlayer playLocalFile:path onView:view];
    [self videoPane];
}

- (void)addObserver{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeRotate:) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
}

- (void)removeObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)changeRotate:(NSNotification*)noti {
    
    if ([[UIDevice currentDevice] orientation] == UIInterfaceOrientationPortrait
        || [[UIDevice currentDevice] orientation] == UIInterfaceOrientationPortraitUpsideDown) {
        _isFullScreen = NO;
    } else {
        _isFullScreen = YES;
    }
    
    [self autoSetDeviceRotate:[[UIDevice currentDevice] orientation]];
}

- (void)autoSetDeviceRotate:(UIDeviceOrientation)orientation{
    [UIView animateWithDuration:0.25 animations:^{
        [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:orientation] forKey:@"orientation"];
        [self settingSubViewFrames];
    }];
}



@end
