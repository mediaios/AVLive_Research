//
//  MIVideoPlayerPane.m
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/15.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import "MIVideoPlayerPane.h"
#import <MediaPlayer/MediaPlayer.h>
#import "MISlider.h"
#import "MIVideoPlayerHelper.h"


const NSUInteger TopViewH = 40;
const NSUInteger BottomViewH = 40;
const NSUInteger CenterBtnH = 40;
const NSUInteger CenterBtnW = 40;
const NSUInteger MIFontSize = 15;

@interface MIVideoPlayerPane()<UIGestureRecognizerDelegate>

//全屏
@property (nonatomic,strong) UIView *fullScreenView;

//快进&快退显示view
@property (nonatomic,strong) UIView  *quickTimeView;
@property (nonatomic,strong) UIImageView *quickOrientationImageV;
@property (nonatomic,strong) UILabel *quickTimeLabel;

//顶部背景图
@property (nonatomic,strong) UIView *topView;
@property (nonatomic,strong) UIButton *backBtn;
@property (nonatomic,strong) UIButton *fullScreenBtn;

@property (nonatomic,strong) UIView   *bottomView;
@property (nonatomic,strong) UILabel  *currentLabel;
@property (nonatomic,strong) UILabel  *totalLabel;

@property (nonatomic,strong) MISlider *videoSlider;
@property (nonatomic,strong) MPVolumeView *volumeView;
@property (nonatomic,strong) UISlider* volumeViewSlider;

@property (nonatomic,strong) UIButton *centerPlayBtn;

@property (nonatomic,strong) NSTimer *hideTimer;
// 手势事件
@property (nonatomic,strong) UIPanGestureRecognizer *sliderGesture;
@property (nonatomic,strong) UITapGestureRecognizer *singleClickGesture;


@property (nonatomic,assign) CGRect paneFrame;
@property (nonatomic,assign) CGPoint startPoint;
@property (nonatomic,assign) CGPoint lastPoint;
@property (nonatomic,assign) CGFloat fastCurrentTime;

@property (nonatomic,assign) BOOL isShowControl;
@property (nonatomic,assign) BOOL isSliderDotMoving;
@property (nonatomic,assign) BOOL isStartPan;
@property (nonatomic,assign) BOOL isQuicking;

@end

@implementation MIVideoPlayerPane

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _paneFrame = frame;
        self.layer.masksToBounds = YES;
        [self createUI];
    }
    return self;
}

- (void)createUI
{
    self.volumeView.frame = self.bounds;
    self.fullScreenView.frame = self.bounds;
    self.quickTimeView.frame = self.bounds;
    
    self.topView.frame = CGRectMake(0, 0, _paneFrame.size.width, TopViewH);
    self.backBtn.frame = CGRectMake(5, 0, 40, TopViewH);
    
    self.quickOrientationImageV.frame = CGRectMake(_paneFrame.size.width/2 - 50/2, _paneFrame.size.height/2-5-50/2, 50, 50);
    self.quickTimeLabel.frame = CGRectMake(_paneFrame.size.width/2 - 200/2, _paneFrame.size.height/2+5, 200, 60);
    
    self.bottomView.frame = CGRectMake(0, _paneFrame.size.height - BottomViewH, _paneFrame.size.width, BottomViewH);
    self.centerPlayBtn.frame = CGRectMake(_paneFrame.size.width/2 - CenterBtnW/2 , _paneFrame.size.height/2 - CenterBtnH/2, CenterBtnW, CenterBtnH);
    self.currentLabel.frame = CGRectMake(15, 0, 50, BottomViewH);
    self.fullScreenBtn.frame = CGRectMake(_paneFrame.size.width-40-15, 0, 40, BottomViewH);
    self.totalLabel.frame = CGRectMake(_paneFrame.size.width - 50 - 40 - 15 - 5 , 0, 50, BottomViewH);
    self.videoSlider.frame = CGRectMake(CGRectGetMaxX(self.currentLabel.frame) + 5, 0, (_paneFrame.size.width - self.currentLabel.frame.size.width - self.totalLabel.frame.size.width - 15*2 - 5*3 - 40) , BottomViewH);
    
    // 添加事件
    [self.fullScreenView addGestureRecognizer:self.sliderGesture];
    [self.fullScreenView addGestureRecognizer:self.singleClickGesture];
}

- (void)hideControlView{
    if (_hideTimer) {
        [_hideTimer invalidate];
        _hideTimer = nil;
    }
    _hideTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(judgeHideOrNot) userInfo:nil repeats:NO];
}

- (void)judgeHideOrNot{
    if (!_isShowControl) return;
    if (self.isQuicking) return;
    _isShowControl = NO;
    [self showOrHideControlView];
}

- (void)showOrHideControlView{
    CGFloat alpha = 0;
    if (_isShowControl) {
        alpha = 1;
    }
    self.sliderGesture.enabled = self.fullScreenBtn.selected ?  YES : _isShowControl;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.topView.alpha = alpha;
        self.bottomView.alpha = alpha;
        self.centerPlayBtn.alpha = alpha;
    } completion:^(BOOL finished) {
        if (self.isShowControl) {
            [self hideControlView];
        }
    }];
}

- (UIView *)fullScreenView{
    if (!_fullScreenView) {
        _fullScreenView = [[UIView alloc] init];
        [self addSubview:_fullScreenView];
    }
    return _fullScreenView;
}

- (UIView *)quickTimeView
{
    if (!_quickTimeView) {
        _quickTimeView = [[UIView alloc] init];
        _quickTimeView.hidden = YES;
        [self.fullScreenView addSubview:_quickTimeView];
    }
    return _quickTimeView;
}

- (UIImageView *)quickOrientationImageV
{
    if (!_quickOrientationImageV) {
        _quickOrientationImageV = [[UIImageView alloc] init];
        _quickOrientationImageV.image = [UIImage imageNamed:@"fast_forward"];
        [self.quickTimeView addSubview:_quickOrientationImageV];
    }
    return _quickOrientationImageV;
}

- (UILabel *)quickTimeLabel{
    if (!_quickTimeLabel) {
        _quickTimeLabel = [[UILabel alloc] init];
        _quickTimeLabel.textColor = [UIColor whiteColor];
        _quickTimeLabel.font = [UIFont systemFontOfSize:32];
        _quickTimeLabel.textAlignment = NSTextAlignmentCenter;
        [self.quickTimeView addSubview:_quickTimeLabel];
    }
    return _quickTimeLabel;
}

//顶部
- (UIView *)topView{
    if (!_topView) {
        _topView = [[UIView alloc] init];
        _topView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        [self addSubview:_topView];
    }
    return _topView;
}

- (UIButton *)backBtn{
    if (!_backBtn) {
        _backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_backBtn setImage:[UIImage imageNamed:@"back"] forState:UIControlStateNormal];
        [_backBtn addTarget:self action:@selector(backBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [self.topView addSubview:_backBtn];
    }
    return _backBtn;
}

- (UIButton *)fullScreenBtn{
    if (!_fullScreenBtn) {
        _fullScreenBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_fullScreenBtn setImage:[UIImage imageNamed:@"normal_screen"] forState:UIControlStateNormal];
        [_fullScreenBtn setImage:[UIImage imageNamed:@"full_screen"] forState:UIControlStateSelected];
        [_fullScreenBtn addTarget:self action:@selector(fullScreenBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomView addSubview:_fullScreenBtn];
    }
    return _fullScreenBtn;
}

//底部背景视图
- (UIView *)bottomView{
    if (!_bottomView) {
        _bottomView = [[UIView alloc] init];
        _bottomView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        [self addSubview:_bottomView];
    }
    return _bottomView;
}

- (UILabel *)currentLabel{
    if (!_currentLabel) {
        _currentLabel = [[UILabel alloc] init];
        _currentLabel.text = @"00:00";
        _currentLabel.textColor = [UIColor whiteColor];
        _currentLabel.textAlignment = NSTextAlignmentCenter;
        _currentLabel.font = [UIFont systemFontOfSize:MIFontSize];
        [self.bottomView addSubview:_currentLabel];
    }
    return _currentLabel;
}

- (UILabel *)totalLabel{
    if (!_totalLabel) {
        _totalLabel = [[UILabel alloc] init];
        _totalLabel.text = @"00:00";
        _totalLabel.textColor = [UIColor whiteColor];
        _totalLabel.textAlignment = NSTextAlignmentCenter;
        _totalLabel.font = [UIFont systemFontOfSize:MIFontSize];
        [self.bottomView addSubview:_totalLabel];
    }
    return _totalLabel;
}

- (UIButton *)centerPlayBtn
{
    if (!_centerPlayBtn) {
        _centerPlayBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_centerPlayBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
        [_centerPlayBtn setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateSelected];
        _centerPlayBtn.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        _centerPlayBtn.layer.cornerRadius = CenterBtnH/2;
        [_centerPlayBtn addTarget:self action:@selector(centerPlayButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_centerPlayBtn];
    }
    return _centerPlayBtn;
}

- (MISlider *)videoSlider{
    if (!_videoSlider) {
        _videoSlider = [[MISlider alloc] initWithFrame:CGRectMake(CGRectGetMaxX(self.currentLabel.frame) + 5, 0, (_paneFrame.size.width - self.currentLabel.frame.size.width - self.totalLabel.frame.size.width - 15*2 - 5*3 - 40) , BottomViewH)];
        UIImage *normalImage =  [MIVideoPlayerHelper generateImageWithColor:[UIColor redColor] radius:5.0];
        UIView *highlightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 12)];
        highlightView.layer.cornerRadius = 6;
        highlightView.layer.masksToBounds = YES;
        highlightView.backgroundColor = [UIColor redColor];
        UIImage *highlightImage = [MIVideoPlayerHelper generateImageWithView:highlightView];
        
        [_videoSlider setDotImage:normalImage forState:UIControlStateNormal];
        [_videoSlider setDotImage:highlightImage forState:UIControlStateHighlighted];
        
        [_videoSlider addTarget:self action:@selector(sliderValueChange:) forControlEvents:UIControlEventValueChanged];
        [_videoSlider addTarget:self action:@selector(sliderTouchEnd:) forControlEvents:UIControlEventEditingDidEnd];
        [self.bottomView addSubview:_videoSlider];
    }
    return _videoSlider;
}

- (void)sliderValueChange:(MISlider *)slider{
    _isSliderDotMoving = YES;
    self.currentLabel.text = [self timeFormatted:slider.playProgress * self.totalTime];
}

- (void)sliderTouchEnd:(MISlider *)slider{
    if (_delegate && [_delegate respondsToSelector:@selector(videoPlayerPane:didPlayToTime:)]) {
        [_delegate videoPlayerPane:self didPlayToTime:slider.playProgress * self.totalTime];
    }
    _isSliderDotMoving = NO;
    [self hideControlView];
    
}

- (MPVolumeView *)volumeView {
    if (_volumeView == nil) {
        _volumeView  = [[MPVolumeView alloc] init];
        [_volumeView sizeToFit];
        for (UIView *view in [_volumeView subviews]){
            if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
                self.volumeViewSlider = (UISlider*)view;
                break;
            }
        }
    }
    return _volumeView;
}

- (UIPanGestureRecognizer *)sliderGesture
{
    if (!_sliderGesture) {
        _sliderGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(sliderGestureTouch:)];
    }
    return _sliderGesture;
}

- (void)sliderGestureTouch:(UIPanGestureRecognizer *)sliderGestureTouch
{
    CGPoint touchPoint = [sliderGestureTouch translationInView:self];
    static int changeXorY = 0;
    if (sliderGestureTouch.state == UIGestureRecognizerStateBegan) {
        _startPoint = touchPoint;
        _lastPoint = touchPoint;
        _isStartPan = YES;
        self.isQuicking = YES;
        _fastCurrentTime = self.currentTime;
        changeXorY = 0;
        self.centerPlayBtn.hidden = YES;
    }else if (sliderGestureTouch.state == UIGestureRecognizerStateChanged){
        CGFloat change_X = touchPoint.x - _startPoint.x;
        CGFloat change_Y = touchPoint.y - _startPoint.y;
        
        if (_isStartPan) {
            if (fabs(change_X) > fabs(change_Y)) {
                changeXorY = 0;   // 横向滑动:改变进度
            }else{
                changeXorY = 1;   // 纵向滑动:改变音量
            }
            _isStartPan = NO;
        }
        changeXorY == 0 ? [self changeVideoPlayProgress:touchPoint] :  [self changeVolume:touchPoint];
    }else if (sliderGestureTouch.state == UIGestureRecognizerStateEnded){
        self.quickTimeView.hidden = YES;
        self.centerPlayBtn.hidden = NO;
        self.isQuicking = NO;
        if (changeXorY == 0) {
            if (_delegate && [_delegate respondsToSelector:@selector(videoPlayerPane:didPlayToTime:)])
                [_delegate videoPlayerPane:self didPlayToTime:_fastCurrentTime];
        }
        [self hideControlView];
    }else if(sliderGestureTouch.state == UIGestureRecognizerStateCancelled){
        self.quickTimeView.hidden = YES;
        self.centerPlayBtn.hidden = NO;
        self.isQuicking = NO;
    }
}

- (void)changeVideoPlayProgress:(CGPoint)touchPoint
{
    self.quickTimeView.hidden = NO;
    if (touchPoint.x - _lastPoint.x >= 1) {
        self.quickOrientationImageV.image = [UIImage imageNamed:@"fast_forward"];
        _lastPoint = touchPoint;
        _fastCurrentTime += 2;
        if (_fastCurrentTime > self.totalTime) {
            _fastCurrentTime = self.totalTime;
        }
    }
    if (touchPoint.x - _lastPoint.x <= - 1) {
        self.quickOrientationImageV.image = [UIImage imageNamed:@"rewind"];
        _lastPoint = touchPoint;
        _fastCurrentTime -= 2;
        if (_fastCurrentTime < 0) {
            _fastCurrentTime = 0;
        }
    }
    
    NSString *currentTimeString = [self timeFormatted:(int)_fastCurrentTime];
    NSString *totalTimeString = [self timeFormatted:(int)self.totalTime];
    self.quickTimeLabel.text = [NSString stringWithFormat:@"%@/%@",currentTimeString,totalTimeString];
}

- (void)changeVolume:(CGPoint)touchPoint
{
    if (touchPoint.y - _lastPoint.y >= 5) {
        _lastPoint = touchPoint;
        self.volumeViewSlider.value -= 0.05;
    }
    if (touchPoint.y - _lastPoint.y <= - 5) {
        _lastPoint = touchPoint;
        self.volumeViewSlider.value += 0.05;
    }
}

- (UITapGestureRecognizer *)singleClickGesture{
    if (!_singleClickGesture) {
        _singleClickGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleClickGestureTouch:)];
        _singleClickGesture.delegate = self;
    }
    return _singleClickGesture;
}

- (void)singleClickGestureTouch:(UITapGestureRecognizer *)singleClickGesture{
    _isShowControl = !_isShowControl;
    [self showOrHideControlView];
}

- (void)fullScreenChanged:(BOOL)isFullScreen frame:(CGRect)frame
{
    self.frame = frame;
    _paneFrame = frame;
    [self createUI];
    self.fullScreenBtn.selected = isFullScreen;
    [self.videoSlider beginFullScreen:isFullScreen];
}

- (NSString *)timeFormatted:(NSInteger)totalSeconds
{
    NSInteger seconds = totalSeconds % 60;
    NSInteger minutes = (totalSeconds / 60) % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld",minutes, seconds];
}

- (void)setTotalTime:(NSUInteger)totalTime{
    _totalTime = totalTime;
    self.totalLabel.text = [self timeFormatted:totalTime];
}

- (void)setCurrentTime:(NSUInteger)currentTime{
    _currentTime = currentTime;
    if (_isSliderDotMoving == NO) {
        self.currentLabel.text = [self timeFormatted:currentTime];
    }
}

- (void)setPlayValue:(CGFloat)playValue{
    _playValue = playValue;
    if (_isSliderDotMoving == NO) {
        self.videoSlider.playProgress = playValue;
    }
}

- (void)setProgress:(CGFloat)progress{
    _progress = progress;
    self.videoSlider.bufferProgress = progress;
}

- (void)playerPanePlay{
    self.centerPlayBtn.selected = YES;
    _isShowControl = YES;
    [self hideControlView];
}

- (void)playerPanePause{
    self.centerPlayBtn.selected = NO;
    _isShowControl = NO;
}

- (void)centerPlayButtonClick:(UIButton *)sender
{
    [self hideControlView];
    
    if (_delegate && [_delegate respondsToSelector:@selector(videoPlayerPane:videoPlayerPaneEvent:)]) {
        MIVideoPlayerPaneEvent paneEvent = MIVideoPlayerPaneEvent_Pause;
        if (!sender.selected)
            paneEvent = MIVideoPlayerPaneEvent_Play;
        [_delegate videoPlayerPane:self videoPlayerPaneEvent:paneEvent];
    }
}

- (void)backBtnClick:(UIButton *)sender
{
    [self hideControlView];
    if (_delegate && [_delegate respondsToSelector:@selector(videoPlayerPane:videoPlayerPaneEvent:)]) {
        [_delegate videoPlayerPane:self videoPlayerPaneEvent:MIVideoPlayerPaneEvent_Back];
    }
}

- (void)fullScreenBtnClick:(UIButton *)sender
{
    [self hideControlView];
    if (_delegate && [_delegate respondsToSelector:@selector(videoPlayerPane:videoPlayerPaneEvent:)]) {
        [_delegate videoPlayerPane:self videoPlayerPaneEvent:MIVideoPlayerPaneEvent_FullScreen];
    }
}

- (void)videoPlayerDidLoading
{

}

- (void)videoPlayerDidBeginPlay
{
    [self hideControlView];
}

- (void)videoPlayerDidEndPlay
{
    
}

- (void)videoPlayerDidFailedPlay
{
    
}

#pragma mark - UIGestureRecognizer Delegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    
    if ([touch.view isDescendantOfView:self.fullScreenView]) {
        return YES;
    }
    return NO;
}


@end
