//
//  MIPushStreamVC.m
//  MILive
//
//  Created by mediaios on  2019/6/21.
//  Copyright © 2019 iosmediadev@gmail.com. All rights reserved.
//

#import "MIPushStreamVC.h"
#import <AVFoundation/AVFoundation.h>
#import "PSHWH264Encoder.h"
#import "MIRtpmClient.h"
#import "MIAudioRecord.h"

typedef enum MIAppLiveStatus{
    MIAppLiveStatus_Ready = 0,
    MIAppLiveStatus_Livie
}MIAppLiveStatus;

@interface MIPushStreamVC ()<AVCaptureVideoDataOutputSampleBufferDelegate,PSHWH264EncoderDelegate,MIAudioEncoderDelegate>
@property (weak, nonatomic) IBOutlet UIView *m_displayView;
@property (weak, nonatomic) IBOutlet UIButton *liveBtn;

@property (nonatomic,strong) AVCaptureVideoDataOutput *video_output;
@property (nonatomic,strong) AVCaptureSession         *m_session;

@property (nonatomic,strong) MIAudioRecord *audioRecord;
@property (nonatomic,strong) PSHWH264Encoder *psH264Encoder;

@property (nonatomic,assign) MIAppLiveStatus appStatus;

@end

@implementation MIPushStreamVC

- (PSHWH264Encoder *)psH264Encoder
{
    if (!_psH264Encoder) {
        _psH264Encoder = [PSHWH264Encoder getInstance];
        _psH264Encoder.delegate = self;
        [_psH264Encoder settingEncoderParametersWithWidth:480 height:640 fps:30];
    }
    return _psH264Encoder;
}

- (MIAudioRecord *)audioRecord
{
    if (!_audioRecord) {
        _audioRecord = [[MIAudioRecord alloc] init];
        _audioRecord.delegate = self;
    }
    return _audioRecord;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    
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
    [self.audioRecord stopRecorder];
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
    if([session canSetSessionPreset:AVCaptureSessionPreset640x480])
    {
        session.sessionPreset = AVCaptureSessionPreset640x480;
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

- (IBAction)onPressedBtnStartOrStopLive:(id)sender {
    if (self.appStatus == MIAppLiveStatus_Ready ) {
        NSString *localURL = @"rtmp://192.168.187.236:1935/rtmplive/room1";
        if ([[MIRtpmClient getInstance] startRtmpConnect:localURL]) {
            self.psH264Encoder.sps = nil;
            self.psH264Encoder.pps = nil;
            self.appStatus = MIAppLiveStatus_Livie;
            [self.audioRecord startRecorder];
            self.liveBtn.backgroundColor = [UIColor redColor];
            [self.liveBtn setTitle:@"STOP" forState:UIControlStateNormal];
        }
        
    }else{
        self.appStatus = MIAppLiveStatus_Ready;
        self.liveBtn.backgroundColor = [UIColor greenColor];
        [self.liveBtn setTitle:@"LIVE" forState:UIControlStateNormal];
        [self.audioRecord stopRecorder];
    }
}


#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (sampleBuffer) {
        [self.psH264Encoder encoder:sampleBuffer];
    }
}

#pragma mark - PSHWH264EncoderDelegate
- (void)videoEncoder:(PSHWH264Encoder *)encoder sps:(NSData *)sps  pps:(NSData *)pps
{
    if (self.appStatus == MIAppLiveStatus_Livie) {
         [[MIRtpmClient getInstance] sendVideoSps:sps pps:pps];
    }
}

- (void)videoEncoder:(PSHWH264Encoder *)encoder videoData:(NSData *)vData  isKeyFrame:(BOOL)isKey
{
    if (self.appStatus == MIAppLiveStatus_Livie) {
        [[MIRtpmClient getInstance] sendVideoData:vData isKeyFrame:isKey];
    }
}

#pragma mark - MIAudioEncoderDelegate
- (void)audioEncoder:(MIAudioRecord *)encoder audioHeader:(NSData *)audioH
{
    if (self.appStatus == MIAppLiveStatus_Livie) {
        [[MIRtpmClient getInstance] sendAudioHeader:audioH];
    }
}

- (void)audioEncoder:(MIAudioRecord *)encoder audioData:(NSData *)audioData
{
    if (self.appStatus == MIAppLiveStatus_Livie) {
        [[MIRtpmClient getInstance] sendAudioData:audioData];
    }
}

@end


