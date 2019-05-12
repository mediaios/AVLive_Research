//
//  MiVideoCollectVC.m
//  MiVideoCollection
//
//  Created by mediaios on 2019/5/12.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MiVideoCollectVC.h"
#import "MICalculator.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#define MiMaxZoomFactor 5.0f
#define MiPrinchVelocityDividerFactor 20.0f

typedef enum{
    MiCameraType_None = 0,
    MiCameraType_Front,
    MiCameraType_Back
}MiCameraType;

@interface MiVideoCollectVC ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic,strong) AVCaptureVideoDataOutput *video_output;
@property (nonatomic,strong) AVCaptureDeviceInput *video_input;
@property (nonatomic,strong) AVCaptureSession  *m_session;
@property (nonatomic,assign) AVCaptureTorchMode m_torchMode;
@property (nonatomic,assign) MiCameraType m_cameraType;
@property (nonatomic,assign) BOOL isTakedPhoto;

@property (weak, nonatomic) IBOutlet UIView *m_displayView;

@property (weak, nonatomic) IBOutlet UILabel *videoConfigLabel;
@property (nonatomic,strong) NSTimer *videoParamTimer;

@property (weak, nonatomic) IBOutlet UIButton *flashBtn;
@property (weak, nonatomic) IBOutlet UIButton *switchBtn;


@end

@implementation MiVideoCollectVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
     [self startCaptureSession];
    UIPinchGestureRecognizer *zoomGR = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(captureZoom:)];
    [self.m_displayView addGestureRecognizer:zoomGR];
    
    _m_torchMode = AVCaptureTorchModeAuto;
    _isTakedPhoto = NO;
    
     _videoParamTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(showVideoParams) userInfo:nil repeats:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self startPreview];
    
    if (_videoParamTimer) {
        [_videoParamTimer setFireDate:[NSDate date]];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _videoParamTimer.fireDate = [NSDate distantFuture];
}

- (void)showVideoParams
{
    int videoFPS = [MICalculator getCaptureVideoFPS];
    NSString *resolution = @"others";
    if ([_m_session.sessionPreset isEqualToString:AVCaptureSessionPreset1920x1080]) {
        resolution = @"1080p";
    }else if([_m_session.sessionPreset isEqualToString:AVCaptureSessionPreset1280x720]){
        resolution = @"720p";
    }
    self.videoConfigLabel.text =[NSString stringWithFormat:@"v fps: %d | resolution:%@",videoFPS,resolution];
}

- (IBAction)onpressedBtnDismiss:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        [self stopPreview];
    }];
}

- (void)startCaptureSession
{
    NSError *error = nil;
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    if ([session canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
        session.sessionPreset = AVCaptureSessionPreset1920x1080;
    }else{
        session.sessionPreset = AVCaptureSessionPresetHigh;
    }
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    _video_input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error || !_video_input) {
        NSLog(@"get input device error...");
        return;
    }
    [session addInput:_video_input];
    
    _video_output = [[AVCaptureVideoDataOutput alloc] init];
    [session addOutput:_video_output];
    
    // Specify the pixel format
    _video_output.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                                                              forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    _video_output.alwaysDiscardsLateVideoFrames = NO;
    dispatch_queue_t video_queue = dispatch_queue_create("MIVideoQueue", NULL);
    [_video_output setSampleBufferDelegate:self queue:video_queue];
    
    [_video_output setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];

    
    CMTime frameDuration = CMTimeMake(1, 30);
    BOOL frameRateSupported = NO;
    
    for (AVFrameRateRange *range in [device.activeFormat videoSupportedFrameRateRanges]) {
        if (CMTIME_COMPARE_INLINE(frameDuration, >=, range.minFrameDuration) &&
            CMTIME_COMPARE_INLINE(frameDuration, <=, range.maxFrameDuration)) {
            frameRateSupported = YES;
        }
    }
    
    if (frameRateSupported && [device lockForConfiguration:&error]) {
        [device setActiveVideoMaxFrameDuration:frameDuration];
        [device setActiveVideoMinFrameDuration:frameDuration];
        [device unlockForConfiguration];
    }
    
    [self adjustVideoStabilization];
    _m_session = session;
    
    
    CALayer *previewViewLayer = [self.m_displayView layer];
    previewViewLayer.backgroundColor = [[UIColor blackColor] CGColor];
    
    AVCaptureVideoPreviewLayer *newPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_m_session];
    
    [newPreviewLayer setFrame:[UIApplication sharedApplication].keyWindow.bounds];
    
    [newPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    //    [previewViewLayer insertSublayer:newPreviewLayer atIndex:2];
    [previewViewLayer insertSublayer:newPreviewLayer atIndex:0];
}

- (void)adjustVideoStabilization
{
    NSArray *devices = [AVCaptureDevice devices];
    for (AVCaptureDevice *device in devices) {
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device.activeFormat isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeAuto]) {
                for (AVCaptureConnection *connection in _video_output.connections) {
                    for (AVCaptureInputPort *port in [connection inputPorts]) {
                        if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                            if (connection.supportsVideoStabilization) {
                                connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeStandard;
                                NSLog(@"now videoStabilizationMode = %ld",(long)connection.activeVideoStabilizationMode);
                            }else{
                                NSLog(@"connection does not support video stablization");
                            }
                        }
                    }
                }
            }else{
                NSLog(@"device does not support video stablization");
            }
        }
    }
}

- (void)startPreview
{
    if (![_m_session isRunning]) {
        [_m_session startRunning];
    }
}

- (void)stopPreview
{
    if ([_m_session isRunning]) {
        [_m_session stopRunning];
    }
}

#pragma mark -AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    [MICalculator calculatorCaptureFPS];
    
    if (_isTakedPhoto == YES) {
        UIImage *imgScreen = nil;
        imgScreen = [self convertSameBufferToUIImage:sampleBuffer];
        if (!imgScreen) {
            NSLog(@"获取图片失败...");
        }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [[self class] saveImageToSysphotos:imgScreen];
        });
        _isTakedPhoto = NO;
    }
    
//    NSLog(@"%s",__func__);
}

// 有丢帧时，此代理方法会触发
- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"MediaIOS: 丢帧...");
}

#pragma mark -修改视频采集参数

// 修改分辨率
- (IBAction)onPressedBtnChangeResolutionTo720p:(id)sender {
    [[self class] resetSessionPreset:_m_session resolution:720];
}

- (IBAction)onPressedBtnChangeResolutionTo1080p:(id)sender {
     [[self class] resetSessionPreset:_m_session resolution:1080];
}

/**
 *  Reset resolution
 *
 *  @param m_session     AVCaptureSession instance
 *  @param resolution
 */
+ (void)resetSessionPreset:(AVCaptureSession *)m_session resolution:(int)resolution
{
    [m_session beginConfiguration];
    switch (resolution) {
        case 1080:
            m_session.sessionPreset = [m_session canSetSessionPreset:AVCaptureSessionPreset1920x1080] ? AVCaptureSessionPreset1920x1080 : AVCaptureSessionPresetHigh;
            break;
        case 720:
            m_session.sessionPreset = [m_session canSetSessionPreset:AVCaptureSessionPreset1280x720] ? AVCaptureSessionPreset1280x720 : AVCaptureSessionPresetMedium;
            break;
        case 480:
            m_session.sessionPreset = [m_session canSetSessionPreset:AVCaptureSessionPreset640x480] ? AVCaptureSessionPreset640x480 : AVCaptureSessionPresetMedium;
            break;
        case 360:
            m_session.sessionPreset = AVCaptureSessionPresetMedium;
            break;
            
        default:
            break;
    }
    [m_session commitConfiguration];
}

// 修改fps
- (IBAction)onpressedBtnChangeFpsTo15:(id)sender {
    [[self class] settingFrameRate:15];
}

- (IBAction)onpressedBtnChangeFpsTo30:(id)sender {
    [[self class] settingFrameRate:30];
}

+ (void)settingFrameRate:(int)frameRate
{
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [captureDevice lockForConfiguration:NULL];
    @try {
        [captureDevice setActiveVideoMinFrameDuration:CMTimeMake(1, frameRate)];
        [captureDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, frameRate)];
    } @catch (NSException *exception) {
        NSLog(@"MediaIOS, 设备不支持所设置的分辨率，错误信息：%@",exception.description);
    } @finally {
        
    }
    
    [captureDevice unlockForConfiguration];
}

// 为预览层添加捏合手势
- (void)captureZoom:(UIPinchGestureRecognizer *)recognizer
{
    [[self class] zoomCapture:recognizer];
}

+ (void)zoomCapture:(UIPinchGestureRecognizer *)recognizer
{
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [videoDevice formats];
    if ([recognizer state] == UIGestureRecognizerStateChanged) {
        NSError *error = nil;
        if ([videoDevice lockForConfiguration:&error]) {
            CGFloat desiredZoomFactor = videoDevice.videoZoomFactor + atan2f(recognizer.velocity, MiPrinchVelocityDividerFactor);
            videoDevice.videoZoomFactor = desiredZoomFactor <= MiMaxZoomFactor ? MAX(1.0, MIN(desiredZoomFactor, videoDevice.activeFormat.videoMaxZoomFactor)) : MiMaxZoomFactor ;
            [videoDevice unlockForConfiguration];
        } else {
            NSLog(@"error: %@", error);
        }
    }
    
}

#pragma mark -相机操作

- (IBAction)onpressedBtnSwitchFlash:(id)sender {
    [self switchTorch];
    
    self.m_torchMode == AVCaptureTorchModeOn ? [self.flashBtn setTitle:@"Off" forState:UIControlStateNormal] : [self.flashBtn setTitle:@"flash" forState:UIControlStateNormal] ;
}


// 打开关闭闪光灯
-(void)switchTorch
{
    [_m_session beginConfiguration];
    [[_video_input device] lockForConfiguration:NULL];
    
    self.m_torchMode = [_video_input device].torchMode == AVCaptureTorchModeOn ? AVCaptureTorchModeOff : AVCaptureTorchModeOn;
    
    if ([[_video_input device] isTorchModeSupported:_m_torchMode ]) {
        [_video_input device].torchMode = self.m_torchMode;
    }
    [[_video_input device] unlockForConfiguration];
    [_m_session commitConfiguration];
}

- (IBAction)onpressedBtnSwitchCamera:(id)sender {
    [self switchCamera];
    self.m_cameraType == MiCameraType_Back ? [self.switchBtn setTitle:@"front" forState:UIControlStateNormal] : [self.switchBtn setTitle:@"back" forState:UIControlStateNormal];
}

// 切换摄像头
- (void)switchCamera
{
    [_m_session beginConfiguration];
    if ([[_video_input device] position] == AVCaptureDevicePositionBack) {
        NSArray * devices = [AVCaptureDevice devices];
        for(AVCaptureDevice * device in devices) {
            if([device hasMediaType:AVMediaTypeVideo]) {
                if([device position] == AVCaptureDevicePositionFront) {
                    [self rePreviewWithCameraType:MiCameraType_Front device:device];
                    break;
                }
            }
        }
    }else{
        NSArray * devices = [AVCaptureDevice devices];
        for(AVCaptureDevice * device in devices) {
            if([device hasMediaType:AVMediaTypeVideo]) {
                if([device position] == AVCaptureDevicePositionBack) {
                    [self rePreviewWithCameraType:MiCameraType_Back device:device];
                    break;
                }
            }
        }
    }
    [_m_session commitConfiguration];
}

- (void)rePreviewWithCameraType:(MiCameraType)cameraType device:(AVCaptureDevice *)device {
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                        error:&error];
    if (!input) return;
    
    [_m_session removeInput:_video_input];
    // set current m_session can accept high preset otherwise if back is 4k switch to 2k addInput add is 4k will error
    _m_session.sessionPreset = AVCaptureSessionPresetLow;
    if ([_m_session canAddInput:input])  {
        [_m_session addInput:input];
    }else {
        return;
    }
    _video_input      = input;
    _m_cameraType    = cameraType;
    NSString *preset = AVCaptureSessionPreset1280x720;
    if([device supportsAVCaptureSessionPreset:preset] && [_m_session canSetSessionPreset:preset]) {
        _m_session.sessionPreset = preset;
    }else {
        NSString *sesssionPreset = AVCaptureSessionPreset1280x720;
        if(![sesssionPreset isEqualToString:preset]) {
            _m_session.sessionPreset = sesssionPreset;
        }
    }
}

// 拍照：截屏并保存d到相册
- (IBAction)onpressedBtnPhoto:(id)sender {
    self.isTakedPhoto = YES;
}

- (UIImage *)convertSameBufferToUIImage:(CMSampleBufferRef)sampleBuffer
{
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    // 得到pixel buffer的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    // 释放context和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    // 用Quartz image创建一个UIImage对象image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    return (image);
}

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    // NSLog(@"imageFromSampleBuffer: called");
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    uint8_t   *baseAddress       = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the number of bytes per row for the pixel buffer
    size_t    bytesPerRow        = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t    width              = CVPixelBufferGetWidth(imageBuffer);
    size_t    height             = CVPixelBufferGetHeight(imageBuffer);
//
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = NULL;
    // if width > height : landscape mode, otherwise : portrait mode.
    context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                        bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    if (context == NULL) {
        CVPixelBufferUnlockBaseAddress(imageBuffer,0);
        CGColorSpaceRelease(colorSpace);
        NSLog(@"MediaIOS, imageFromSampleBuffer, context is null...");
        return NULL;
    }
    
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return image;
}

+ (void)saveImageToSysphotos:(UIImage *)image
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeImageToSavedPhotosAlbum:image.CGImage metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"MediaIos, save photo to photos error, error info: %@",error.description);
        }else{
            NSLog(@"MediaIos, save photo success...");
        }
    }];
}






@end
