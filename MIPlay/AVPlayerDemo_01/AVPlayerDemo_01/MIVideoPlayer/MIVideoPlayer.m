//
//  MIVideoPlayer.m
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/15.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import "MIVideoPlayer.h"
#import <AVFoundation/AVFoundation.h>

@interface MIVideoPlayer()
@property (nonatomic,copy) NSString *mUrl;
@property (nonatomic,strong) AVPlayer *mPlayer;
@property (nonatomic,strong) AVPlayerItem *mPlayerItem;
@property (nonatomic,strong) AVPlayerLayer *mPlayerLayer;
@property (nonatomic,strong) UIView *mContainer;
@property (nonatomic,strong) NSMutableArray *mBufferedArray; // 用于保存已经缓冲的数据
@property (nonatomic, assign) BOOL playButtonState;
@end

@implementation MIVideoPlayer


- (void)playUrl:(NSString *)url onView:(UIView *)videoView
{
    /*** 校验参数合法性 ***/
    _mUrl = url;
    _mContainer = videoView;
    [self setupParams];
    _mContainer.layer.masksToBounds = YES;
    NSURL *vurl = [NSURL URLWithString:url];
    self.mPlayerItem = [AVPlayerItem playerItemWithURL:vurl];
    [self createAVPlayer];
}

- (void)playLocalFile:(NSString *)path onView:(UIView *)videoView
{
    _mContainer = videoView;
    [self setupParams];
    _mContainer.layer.masksToBounds = YES;
    NSURL *url = [NSURL fileURLWithPath:path];
    AVAsset *movieAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    self.mPlayerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
    [self createAVPlayer];
}

- (void)createAVPlayer
{
    self.mPlayer = [AVPlayer playerWithPlayerItem:self.mPlayerItem];
    self.mPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.mPlayer];
    [self setupLayerFrameWithVideoSize:self.videoSize];
    [self addObserver];
}

- (void)setupParams
{
    self.playButtonState = YES;
    self.mBufferedArray = [NSMutableArray array];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
}

- (void)setupLayerFrameWithVideoSize:(CGSize)vSize
{
    if (vSize.width) {
        CGSize size;
        size.width = self.mContainer.bounds.size.width;
        size.height = size.width/vSize.width * vSize.height;
        CGFloat x = 0;
        CGFloat y = (self.mContainer.bounds.size.height - size.height)*0.5;
        self.mPlayerLayer.frame = CGRectMake(x, y, size.width, size.height);
    }else{
        self.mPlayerLayer.frame = CGRectMake(0, 0, self.mContainer.bounds.size.width, self.mContainer.bounds.size.height);
    }
    
    [self handleShowViewSublayers];
}

- (void)settingFrame:(CGRect)frame
{
    self.mContainer.frame = frame;
    self.mPlayerLayer.frame = frame;
}

- (void)handleShowViewSublayers
{
    for (UIView *view in _mContainer.subviews) {
        [view removeFromSuperview];
    }
    [_mContainer.layer addSublayer:self.mPlayerLayer];
}

- (void)addObserver
{
    __weak typeof(self) weakSelf = self;
    [self.mPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        CGFloat current = CMTimeGetSeconds(time);
        CGFloat total = CMTimeGetSeconds(weakSelf.mPlayerItem.duration);
        if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(videoPlayer:totalTime:currentTime:)]) {
            [weakSelf.delegate videoPlayer:weakSelf totalTime:total currentTime:current];
        }
    }];
    [self.mPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [self.mPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [self.mPlayerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];//监听到当前没有缓冲数据
}

- (void)removeObserver
{
    [self.mPlayerItem removeObserver:self forKeyPath:@"status"];
    [self.mPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.mPlayerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.mPlayer replaceCurrentItemWithPlayerItem:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = playerItem.status;
        switch (status) {
            case AVPlayerItemStatusUnknown:
            case AVPlayerItemStatusFailed:{
                NSLog(@"播放失败");
            }
                break;
                
            case AVPlayerItemStatusReadyToPlay:{
                //                self.player.muted = self.mute;
//                [self play];
//                [self handleShowViewSublayers];
//                NSLog(@"准备播放");
            }
                break;
                
            default:
                break;
        }
    }
    else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        NSTimeInterval current = [self loadedVideo];
        CMTime duration = playerItem.duration;
        CGFloat totalDuration = CMTimeGetSeconds(duration);
        CGFloat progress = current / totalDuration;
        if (_delegate && [_delegate respondsToSelector:@selector(videoPlayer:bufferProgress:)]) {
            [_delegate videoPlayer:self bufferProgress:progress];
        }
        
        //        self.duration = totalDuration;
        //        self.currentBufferValue = current;
        //
        //        [self handleBuffer];
    }
    else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        //        self.isPlaying = NO;
        //        self.isBufferEmpty = YES;
        //        self.lastBufferValue = self.currentBufferValue;
        //
        if (_delegate && [_delegate respondsToSelector:@selector(videoPlayer:videoPlayerState:)]) {
            [_delegate videoPlayer:self videoPlayerState:MIVideoPlayerState_StartBuffer];
        }
        NSLog(@"playbackBufferEmpty");
    }
}

- (void)play
{
    self.playButtonState = YES;
    [self.mPlayer play];
    if (_delegate && [_delegate respondsToSelector:@selector(videoPlayer:videoPlayerState:)]) {
        [_delegate videoPlayer:self videoPlayerState:MIVideoPlayerState_DidPlay];
    }
}

- (void)pause
{
    self.playButtonState = NO;
    [self.mPlayer pause];
    if (_delegate && [_delegate respondsToSelector:@selector(videoPlayer:videoPlayerState:)]) {
        [_delegate videoPlayer:self videoPlayerState:MIVideoPlayerState_DidPause];
    }
}

// 停止播放/清空播放器
- (void)destoryPlayer
{
    if (self.mPlayerItem == nil) return;
    [self.mPlayer pause];
    [self.mPlayer cancelPendingPrerolls];
    if (self.mPlayerLayer) [self.mPlayerLayer removeFromSuperlayer];
    [self removeObserver];
    self.mPlayer = nil;
    self.mPlayerItem = nil;
    [self.mBufferedArray removeAllObjects];
    self.mBufferedArray = nil;
}

- (void)seekPlayFromTime:(float)fromTime
{
    if (self.mPlayer) {
        [self.mPlayer pause];
        [self.mBufferedArray addObject:[self loadedTimeRange]];
//        BOOL isShowActivity = [self isShowActivity:fromTime];
//        if (isShowActivity) {
//            if (_delegate && [_delegate respondsToSelector:@selector(videoPlayer:videoPlayerState:)]) {
//                [_delegate videoPlayer:self videoPlayerState:MIVideoPlayerState_StartBuffer];
//            }
//        }
        __weak typeof(self) weak_self = self;
        [self.mPlayer seekToTime:CMTimeMake(fromTime, 1) completionHandler:^(BOOL finished) {
            __strong typeof(weak_self) strong_self = weak_self;
            if (!strong_self) return;
            [strong_self play];
        }];
    }
}

- (void)playerItemDidPlayToEnd:(NSNotification *)notification
{
    if (_enableReplay) {
        __weak typeof(self) weak_self = self;
        [self.mPlayer seekToTime:CMTimeMake(0, 2) completionHandler:^(BOOL finished) {
            __strong typeof(weak_self) strong_self = weak_self;
            if (!strong_self) return;
            [strong_self.mPlayer play];
        }];
    }else{
        [self pause];
    }
    if (_delegate && [_delegate respondsToSelector:@selector(videoPlayer:videoPlayerState:)]) {
        [_delegate videoPlayer:self videoPlayerState:MIVideoPlayerState_EndPlay];
    }
}

- (NSTimeInterval)loadedVideo {
    NSArray *loadedTimeRanges = [self.mPlayerItem loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;
    return result;
}

- (NSDictionary *)loadedTimeRange{
    NSArray *loadedTimeRanges = [self.mPlayerItem loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSString *start = [NSString stringWithFormat:@"%.2f",startSeconds];
    NSString *duration = [NSString stringWithFormat:@"%.2f",durationSeconds];
    NSDictionary *timeRangeDic = @{@"start" : start, @"duration" : duration};
    
    return timeRangeDic;
}

- (BOOL)isShowActivity:(float)toTime{
    BOOL show = YES;
    
    for (NSDictionary *timeRangeDic in self.mBufferedArray) {
        float start = [timeRangeDic[@"start"] floatValue];
        float duration = [timeRangeDic[@"duration"] floatValue];
        if (start < toTime && toTime < start + duration) {
            show = NO;
            break;
        }
    }
    return show;
}

@end
