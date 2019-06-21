//
//  MIPushStreamVC.m
//  MILive
//
//  Created by mediaios on  2019/6/21.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIPushStreamVC.h"
#import <AVFoundation/AVFoundation.h>
#import "MIHWH264Encoder.h"
#import "MIRtpmClient.h"
#import "MIAudioRecord.h"


@interface MIPushStreamVC ()<AVCaptureVideoDataOutputSampleBufferDelegate,MIHWH264EncoderDelegate>
@property (weak, nonatomic) IBOutlet UIView *m_displayView;
@property (nonatomic,strong) AVCaptureVideoDataOutput *video_output;
@property (nonatomic,strong) AVCaptureSession         *m_session;

@property (nonatomic,strong) MIAudioRecord *audioRecord;
@property (nonatomic,strong) MIHWH264Encoder *hwH264Encoder;
@end

@implementation MIPushStreamVC

- (MIHWH264Encoder *)hwH264Encoder
{
    if (!_hwH264Encoder) {
        _hwH264Encoder = [MIHWH264Encoder getInstance];
        _hwH264Encoder.delegate = self;
        [_hwH264Encoder settingEncoderParametersWithWidth:1080 height:1920 fps:30];
    }
    return _hwH264Encoder;
}

- (MIAudioRecord *)audioRecord
{
    if (!_audioRecord) {
        _audioRecord = [[MIAudioRecord alloc] init];
    }
    return _audioRecord;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[MIRtpmClient getInstance] startRtmpConnect:@"rtmp://148.70.8.134:1935/myapp/test1"];
    [self.audioRecord startRecorder];
    
     [self startCaptureSession];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self startPreview];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stopPreview];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

}


- (IBAction)onPressedBtnDismiss:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
    
- (int)startCaptureSession
{
    NSError *error = nil;
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    if([session canSetSessionPreset:AVCaptureSessionPreset1920x1080])
    {
        session.sessionPreset = AVCaptureSessionPreset1920x1080;
    }
    else
    {
        session.sessionPreset = AVCaptureSessionPresetHigh;
    }
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                        error:&error];
    if (!input) {
        return -1;
    }
    [session addInput:input];
    
    _video_output = [[AVCaptureVideoDataOutput alloc] init];
    [session addOutput:_video_output];
    
    // Specify the pixel format
    _video_output.videoSettings =
    [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    _video_output.alwaysDiscardsLateVideoFrames = NO;
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("videoQueue", NULL);
    [_video_output setSampleBufferDelegate:self queue:queue];
    
    
    for ( AVCaptureConnection *connection in [_video_output connections] )
    {
        for ( AVCaptureInputPort *port in [connection inputPorts] )
        {
            if ( [[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                AVCaptureConnection * videoConnection = connection;
                videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
                if([videoConnection isVideoMinFrameDurationSupported])
                {
                    [videoConnection setVideoMinFrameDuration:CMTimeMake(1, 30)];
                }
            }
        }
    }
    
    [self adjustVideoStabilization];
    
    _m_session = session;
    
    CALayer *previewViewLayer = [self.m_displayView layer];
    previewViewLayer.backgroundColor = [[UIColor blackColor] CGColor];
    
    AVCaptureVideoPreviewLayer *newPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_m_session];
    newPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    [newPreviewLayer setFrame:[UIApplication sharedApplication].keyWindow.bounds];
    
    [newPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [previewViewLayer insertSublayer:newPreviewLayer atIndex:0];
    return 0;
}

-(void)adjustVideoStabilization{
    NSArray *devices = [AVCaptureDevice devices];
    for(AVCaptureDevice *device in devices){
        if([device hasMediaType:AVMediaTypeVideo]){
            if([device.activeFormat isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeAuto]){
                for(AVCaptureConnection *connection in _video_output.connections)
                {
                    for(AVCaptureInputPort *port in [connection inputPorts])
                    {
                        if([[port mediaType] isEqual:AVMediaTypeVideo])
                        {
                            if(connection.supportsVideoStabilization)
                            {
                                connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeStandard;
                                NSLog(@"activeVideoStabilizationMode = %ld",(long)connection.activeVideoStabilizationMode);
                            }else{
                                NSLog(@"connection don't support video stabilization");
                            }
                        }
                    }
                }
            }else{
                NSLog(@"device don't support video stablization");
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


#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (sampleBuffer) {
        [self.hwH264Encoder encoder:sampleBuffer];
    }
    
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection NS_AVAILABLE(10_7, 6_0)
{
//        NSLog(@"%s",__func__);
}

#pragma mark MIHWH264EncoderDelegate
- (void)acceptEncoderData:(uint8_t *)data length:(int)len naluType:(H264Data_NALU_TYPE)naluType
{
    if (data != NULL) {
//        NSLog(@"%s---type:%d",__func__,(int)naluType);
    }
    
}


@end
