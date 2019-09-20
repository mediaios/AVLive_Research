//
//  MISlider.m
//  AVPlayerDemo_01
//
//  Created by mediaios on 2019/8/22.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import "MISlider.h"

const CGFloat MISliderH = 1.5f;

@interface MISlider()

@property (nonatomic, strong) UIImageView *trackImageView;
@property (nonatomic, strong) UIImageView *bufferImageView;
@property (nonatomic, strong) UIImageView *playProgressImageView;
@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, strong) UIImageView *dotImageView;
@property (nonatomic, assign) CGFloat dotTouchSize;
@property (nonatomic, assign) CGFloat dotVisiableSize;
@property (nonatomic,assign) CGRect sliderFrame;

@end

@implementation MISlider

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _sliderFrame = frame;
        _dotTouchSize = _sliderFrame.size.height;
        _dotVisiableSize = 12;
        [self setupColorWithTrackColor:[UIColor grayColor] bufferedCollor:[UIColor whiteColor] playedColor:[UIColor redColor]];
        self.bgView.backgroundColor = [UIColor clearColor];
        self.dotImageView.backgroundColor = [UIColor whiteColor];
        
        [self createUI];
    }
    return self;
}

- (void)createUI{
    self.trackImageView.frame = CGRectMake(0, (_sliderFrame.size.height - MISliderH) * 0.5, _sliderFrame.size.width, MISliderH);
    self.bufferImageView.frame = CGRectMake(0, (_sliderFrame.size.height - MISliderH) * 0.5, _bufferProgress * _sliderFrame.size.width, MISliderH);
    
    self.playProgressImageView.frame = CGRectMake(0, (_sliderFrame.size.height - MISliderH) * 0.5, _playProgress * _sliderFrame.size.width, MISliderH);
    self.bgView.frame = CGRectMake(0, 0, _dotTouchSize, _dotTouchSize);
    self.bgView.center = [self getThumbCenterWithValue:_playProgress];
    self.dotImageView.frame = CGRectMake((_dotTouchSize - _dotVisiableSize) * 0.5, (_dotTouchSize - _dotVisiableSize) * 0.5, _dotVisiableSize, _dotVisiableSize);
}

- (CGPoint)getThumbCenterWithValue:(CGFloat)value{
    CGFloat thumbX = _dotVisiableSize * 0.5 + (_sliderFrame.size.width - _dotVisiableSize) * value;
    CGFloat thumbY = _sliderFrame.size.height * 0.5;
    return CGPointMake(thumbX, thumbY);
}

- (UIImageView *)trackImageView{
    if (!_trackImageView) {
        _trackImageView = [[UIImageView alloc] init];
        _trackImageView.layer.masksToBounds = YES;
        [self addSubview:_trackImageView];
    }
    return _trackImageView;
}

- (UIImageView *)bufferImageView{
    if (!_bufferImageView) {
        _bufferImageView = [[UIImageView alloc] init];
        _bufferImageView.layer.masksToBounds = YES;
        [self addSubview:_bufferImageView];
    }
    return _bufferImageView;
}

- (UIImageView *)playProgressImageView{
    if (!_playProgressImageView) {
        _playProgressImageView = [[UIImageView alloc] init];
        _playProgressImageView.layer.masksToBounds = YES;
        [self addSubview:_playProgressImageView];
    }
    return _playProgressImageView;
}

- (UIView *)bgView{
    if (!_bgView) {
        _bgView = [[UIView alloc] init];
        _bgView.layer.masksToBounds = YES;
        _bgView.userInteractionEnabled = NO;
        [self addSubview:_bgView];
    }
    return _bgView;
}

- (UIImageView *)dotImageView{
    if (!_dotImageView) {
        _dotImageView = [[UIImageView alloc] init];
        _dotImageView.layer.masksToBounds = YES;
        [self.bgView addSubview:_dotImageView];
    }
    return _dotImageView;
}

- (void)setupColorWithTrackColor:(UIColor *)trackColor
                  bufferedCollor:(UIColor *)bufferedCollor
                     playedColor:(UIColor *)playedColor
{
    self.trackImageView.backgroundColor = trackColor;
    self.bufferImageView.backgroundColor = bufferedCollor;
    self.playProgressImageView.backgroundColor = playedColor;
}

- (void)setDotVisiableSize:(CGFloat)dotVisiableSize
{
    _dotVisiableSize = dotVisiableSize;
    [self createUI];
}

- (void)setBufferProgress:(CGFloat)bufferProgress{
    bufferProgress = [self valid:bufferProgress];
    if (_bufferProgress == bufferProgress) {
        return;
    }
    _bufferProgress = bufferProgress;
    self.bufferImageView.frame = CGRectMake(0, (_sliderFrame.size.height - MISliderH) * 0.5, _bufferProgress * _sliderFrame.size.width, MISliderH);
}

- (void)setPlayProgress:(CGFloat)playProgress {
    playProgress = [self valid:playProgress];
    if (_playProgress == playProgress) {
        return;
    }
    _playProgress = playProgress;
    
    self.bgView.center = [self getThumbCenterWithValue:_playProgress];
    self.playProgressImageView.frame = CGRectMake(0, (_sliderFrame.size.height - MISliderH) * 0.5, _playProgress * _sliderFrame.size.width, MISliderH);
}

- (float)valid:(float)f {
    if (isnan(f)) {
        return 0.0;
    }
    if (f < 0.005) {
        return 0.0;
    }
    else if (f > 0.995) {
        f = 1.0;
    }
    return f;
}

#pragma mark- 复写UIControl中的方法
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint location = [touch locationInView:self];
    if (!CGRectContainsPoint(self.bgView.frame, location)) {
        return NO;
    }
    self.dotImageView.highlighted = YES;
    [self sendActionsForControlEvents:UIControlEventEditingDidBegin];
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint location = [touch locationInView:self];
    if (location.x <= CGRectGetWidth(self.bounds) + 10 && location.x >= - 10) {
        self.dotImageView.highlighted = YES;
        self.playProgress = location.x / CGRectGetWidth(self.bounds);
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    self.dotImageView.highlighted = NO;
    [self sendActionsForControlEvents:UIControlEventEditingDidEnd];
}

#pragma mark- public methods
- (void)setDotImage:(UIImage *)dotImage forState:(UIControlState)state
{
    if (state == UIControlStateNormal) {
        self.dotImageView.image = dotImage;
        self.dotImageView.backgroundColor = [UIColor clearColor];
    }
    else if (state == UIControlStateHighlighted) {
        self.dotImageView.highlightedImage = dotImage;
        self.dotImageView.backgroundColor = [UIColor clearColor];
    }
}

- (void)beginFullScreen:(BOOL)isFullScreen
{
    _sliderFrame = self.bounds;
    [self createUI];
}

@end
