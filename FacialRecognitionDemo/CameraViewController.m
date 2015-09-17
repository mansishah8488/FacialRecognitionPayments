//
//  CameraViewController.m
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/26/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import "CameraViewController.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "KairosSDK.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import "UIImageView+WebCache.h"
#import <Parse/Parse.h>


static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

// used for KVO observation of the @"capturingStillImage" property to perform flash bulb animation
//static const NSString *AVCaptureStillImageIsCapturingStillImageContext = @"AVCaptureStillImageIsCapturingStillImageContext";


static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size);
static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size)
{
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)pixel;
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
    CVPixelBufferRelease( pixelBuffer );
}

// create a CGImage with provided pixel buffer, pixel buffer must be uncompressed kCVPixelFormatType_32ARGB or kCVPixelFormatType_32BGRA
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut);
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut)
{
    OSStatus err = noErr;
    OSType sourcePixelFormat;
    size_t width, height, sourceRowBytes;
    void *sourceBaseAddr = NULL;
    CGBitmapInfo bitmapInfo;
    CGColorSpaceRef colorspace = NULL;
    CGDataProviderRef provider = NULL;
    CGImageRef image = NULL;
    
    sourcePixelFormat = CVPixelBufferGetPixelFormatType( pixelBuffer );
    if ( kCVPixelFormatType_32ARGB == sourcePixelFormat )
        bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst;
    else if ( kCVPixelFormatType_32BGRA == sourcePixelFormat )
        bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
    else
        return -95014; // only uncompressed pixel formats
    
    sourceRowBytes = CVPixelBufferGetBytesPerRow( pixelBuffer );
    width = CVPixelBufferGetWidth( pixelBuffer );
    height = CVPixelBufferGetHeight( pixelBuffer );
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    sourceBaseAddr = CVPixelBufferGetBaseAddress( pixelBuffer );
    
    colorspace = CGColorSpaceCreateDeviceRGB();
    
    CVPixelBufferRetain( pixelBuffer );
    provider = CGDataProviderCreateWithData( (void *)pixelBuffer, sourceBaseAddr, sourceRowBytes * height, ReleaseCVPixelBuffer);
    image = CGImageCreate(width, height, 8, 32, sourceRowBytes, colorspace, bitmapInfo, provider, NULL, true, kCGRenderingIntentDefault);
    
bail:
    if ( err && image ) {
        CGImageRelease( image );
        image = NULL;
    }
    if ( provider ) CGDataProviderRelease( provider );
    if ( colorspace ) CGColorSpaceRelease( colorspace );
    *imageOut = image;
    return err;
}

// utility used by newSquareOverlayedImageForFeatures for
static CGContextRef CreateCGBitmapContextForSize(CGSize size);
static CGContextRef CreateCGBitmapContextForSize(CGSize size)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow = (size.width * 4);
    
    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (NULL,
                                     size.width,
                                     size.height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedLast);
    CGContextSetAllowsAntialiasing(context, NO);
    CGColorSpaceRelease( colorSpace );
    return context;
}


#pragma mark - UIImage Rotate methods

@interface UIImage (RotationMethods)
- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees;
@end

@implementation UIImage (RotationMethods)

- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees
{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.size.width, self.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(DegreesToRadians(degrees));
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    //   // Rotate the image context
    CGContextRotateCTM(bitmap, DegreesToRadians(degrees));
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), [self CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end







@interface CameraViewController ()

@property (nonatomic) BOOL isUsingFrontFacingCamera;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic) dispatch_queue_t videoDataOutputQueue;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic,strong) AVCaptureStillImageOutput *stillImageOutput;

@property (nonatomic, strong) UIImage *faceOutlineImage;
@property (nonatomic, strong) CIDetector *faceDetector;


- (void)setupAVCapture;
- (void)teardownAVCapture;

@end

@implementation CameraViewController
@synthesize activityIndicatorView,cardItems,viewForGuidlines,viewForCarousel,imageViewForArrow,viewToEnterPayAmount,viewToAuthorisePayment,imageViewForDetectedImage,textfieldToEnterAmount,labelToDisplayAmount,labelForPersonToPay,labelForPersonDetected,viewForPaymentConfirmation,tableViewForPayHistory,paymentHistoryItems,isCompleteTransaction,imageViewForOutline,isDetectedFace,carousel,personData,friendsList;

@synthesize videoDataOutput = _videoDataOutput;
@synthesize videoDataOutputQueue = _videoDataOutputQueue;

@synthesize faceOutlineImage = _faceOutlineImage;
@synthesize previewView = _previewView;
@synthesize previewLayer = _previewLayer;

@synthesize faceDetector = _faceDetector;
@synthesize stillImageOutput = _stillImageOutput;


@synthesize isUsingFrontFacingCamera = _isUsingFrontFacingCamera;

#pragma mark - Initialise with the Person Model
- (id) initWithPersonData:(PersonData *) persondata friendslist:(NSMutableArray *)friendslist
{
    if(self = [super init])
    {
        self.personData = persondata;
        self.friendsList = friendslist;
    }
    return self;
}


#pragma mark - Setup the Camera View using AVFoundation

- (void)setupAVCapture
{
    NSError *error = nil;
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone){
        [session setSessionPreset:AVCaptureSessionPreset640x480];
    } else {
        [session setSessionPreset:AVCaptureSessionPresetPhoto];
    }
    
    self.imageViewForOutline.image = [UIImage imageNamed:@"img_dottedface.png"];
    
    
    // Select a video device, make an input
    AVCaptureDevice *device;
    
    AVCaptureDevicePosition desiredPosition;
    
    if (self.isUsingFrontFacingCamera)
        desiredPosition = AVCaptureDevicePositionFront;
    else
        desiredPosition = AVCaptureDevicePositionBack;
    
    
    // find the front facing camera
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([d position] == desiredPosition) {
            device = d;
            break;
        }
    }
    // fall back to the default camera.
    if( nil == device )
    {
        self.isUsingFrontFacingCamera = NO;
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    // get the input device
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    if( !error ) {
        
        // add the input to the session
        if ( [session canAddInput:deviceInput] ){
            [session addInput:deviceInput];
        }
        
        // Make a still image output
        self.stillImageOutput = [AVCaptureStillImageOutput new];
        
        //[self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:(__bridge void *)(AVCaptureStillImageIsCapturingStillImageContext)];
        
        if ( [session canAddOutput:self.stillImageOutput] )
            [session addOutput:self.stillImageOutput];
        
        // Make a video data output
        self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
        NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                           [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        [self.videoDataOutput setVideoSettings:rgbOutputSettings];
        [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
        
        // create a serial dispatch queue used for the sample buffer delegate
        // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
        // see the header doc for setSampleBufferDelegate:queue: for more information
        self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
        
        if ( [session canAddOutput:self.videoDataOutput] ){
            [session addOutput:self.videoDataOutput];
        }
        
        // get the output for doing face detection.
        [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
        
        effectiveScale = 1.0;
        
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
        self.previewLayer.backgroundColor = [[UIColor clearColor] CGColor];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        
        CALayer *rootLayer = [self.previewView layer];
        [rootLayer setMasksToBounds:YES];
        [self.previewLayer setFrame:[rootLayer bounds]];
        [rootLayer addSublayer:self.previewLayer];
        [session startRunning];
        
    }
    session = nil;
    if (error) {
        
        [self showAlertMessage:[error localizedDescription] alertViewTitle:[NSString stringWithFormat:@"Failed with error %d", (int)[error code]]];
        
        [self teardownAVCapture];
    }
}

// clean up capture setup
- (void)teardownAVCapture
{
    
    self.videoDataOutput = nil;
    if (self.videoDataOutputQueue) {
        self.videoDataOutputQueue = nil;
    }
    self.isUsingFrontFacingCamera = self.isUsingFrontFacingCamera;
    
    [self.previewLayer removeFromSuperlayer];
    self.previewLayer = nil;
    //self.stillImageOutput = nil;
}


// perform a flash bulb animation using KVO to monitor the value of the capturingStillImage property of the AVCaptureStillImageOutput class
/*- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
 {
 if ( context == (__bridge void *)(AVCaptureStillImageIsCapturingStillImageContext) ) {
 BOOL isCapturingStillImage = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
 
 if ( isCapturingStillImage ) {
 // do flash bulb like animation
 flashView = [[UIView alloc] initWithFrame:[self.previewView frame]];
 [flashView setBackgroundColor:[[UIColor whiteColor] colorWithAlphaComponent:0.75f]];
 [flashView setAlpha:0.f];
 [[[self view] window] addSubview:flashView];
 
 [UIView animateWithDuration:.4f
 animations:^{
 [flashView setAlpha:1.f];
 }
 ];
 }
 else {
 [UIView animateWithDuration:.4f
 animations:^{
 [flashView setAlpha:0.f];
 }
 completion:^(BOOL finished){
 [flashView removeFromSuperview];
 flashView = nil;
 }
 ];
 }
 }
 }*/


// utility routine to display error aleart if takePicture fails
- (void)displayErrorOnMainQueue:(NSError *)error withMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        [self showAlertMessage:[error localizedDescription] alertViewTitle:[NSString stringWithFormat:@"%@ (%d)", message, (int)[error code]]];
    });
}


// find where the video box is positioned within the preview layer based on the video size and gravity
+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity
                          frameSize:(CGSize)frameSize
                       apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
    
    CGRect videoBox;
    videoBox.size = size;
    if (size.width < frameSize.width)
        videoBox.origin.x = (frameSize.width - size.width) / 2;
    else
        videoBox.origin.x = (size.width - frameSize.width) / 2;
    
    if ( size.height < frameSize.height )
        videoBox.origin.y = (frameSize.height - size.height) / 2;
    else
        videoBox.origin.y = (size.height - frameSize.height) / 2;
    
    return videoBox;
}

- (int) exifOrientation: (UIDeviceOrientation) orientation
{
    int exifOrientation;
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    };
    
    switch (orientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            if (self.isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            if (self.isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    return exifOrientation;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // get the image
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
    if (attachments) {
        CFRelease(attachments);
    }
    
    // make sure your device orientation is not locked.
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    
    NSArray *features = [self.faceDetector featuresInImage:ciImage options:@{ CIDetectorSmile : @YES,
                                                                              CIDetectorEyeBlink : @YES,
                                                                              CIDetectorImageOrientation :[NSNumber numberWithInt:[self exifOrientation:curDeviceOrientation]] }];
    if([features count] == 0)
    {
    }else
    {
        for(CIFaceFeature *faceFeature in features)
        {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                if(self.isUsingFrontFacingCamera)
                {
                    if(faceFeature.hasLeftEyePosition && faceFeature.hasRightEyePosition && faceFeature.hasMouthPosition)
                        self.imageViewForOutline.image = [UIImage imageNamed:@"img_detectedface.png"];
                    if(faceFeature.rightEyeClosed && !faceFeature.leftEyeClosed && !isDetectedFace)
                    {
                        isDetectedFace = YES;
                        [self fnToCaptureStillImage];
                    }else if(faceFeature.leftEyeClosed && !faceFeature.rightEyeClosed &&!isDetectedFace)
                    {
                        isDetectedFace = YES;
                        [self fnToCaptureStillImage];
                    }
                }else
                {
                    if(faceFeature.hasLeftEyePosition && faceFeature.hasRightEyePosition && faceFeature.hasMouthPosition && !isDetectedFace)
                    {
                        isDetectedFace = YES;
                        self.imageViewForOutline.image = [UIImage imageNamed:@"img_detectedface.png"];
                        //Image Capturing Code
                    }
                }
                
            });
            
        }
    }
}




// utility routing used during image capture to set up capture orientation
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    AVCaptureVideoOrientation result = (AVCaptureVideoOrientation)deviceOrientation;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
        result = AVCaptureVideoOrientationLandscapeRight;
    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
        result = AVCaptureVideoOrientationLandscapeLeft;
    return result;
}

#pragma mark -
#pragma mark iCarousel methods

- (NSInteger)numberOfItemsInCarousel:(__unused iCarousel *)carousel
{
    return (NSInteger)[self.cardItems count];
}

- (UIView *)carousel:(__unused iCarousel *)carousel viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    UILabel *label = nil;
    UIImageView *imageViewForCard = nil;
    UIImageView *imageViewForSlider = nil;
    
    //create new view if no view is available for recycling
    if (view == nil)
    {
        view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 119.0f,80.0f)];
        view.backgroundColor = [UIColor clearColor];
        
        imageViewForCard = [[UIImageView alloc] initWithFrame:CGRectMake(19, 0, 80.0f, 54.0f)];
        imageViewForCard.backgroundColor = [UIColor clearColor];
        
        label = [[UILabel alloc] initWithFrame:CGRectMake(0, 57, 119.0f, 14.0f)];
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor whiteColor];
        [label setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:11]];
        
        
        imageViewForSlider = [[UIImageView alloc] initWithFrame:CGRectMake(0, 74, 119.0f, 6.0f)];
        imageViewForSlider.image = [UIImage imageNamed:@"img_cardselection.png"];
        imageViewForSlider.backgroundColor = [UIColor clearColor];
        
        [view addSubview:imageViewForCard];
        [view addSubview:imageViewForSlider];
        [view addSubview:label];
    }
    else
    {
        //get a reference to the label in the recycled view
        label = (UILabel *)[view viewWithTag:1];
        imageViewForCard = (UIImageView *) [view viewWithTag:1];
        imageViewForSlider = (UIImageView *) [view viewWithTag:1];
        
    }
    
    //set item label
    //remember to always set any properties of your carousel item
    //views outside of the `if (view == nil) {...}` check otherwise
    //you'll get weird issues with carousel item content appearing
    //in the wrong place in the carousel
    //label.text = [self.cardItems[(NSUInteger)index] stringValue];
    
    label.text = [[self.cardItems objectAtIndex:(NSUInteger) index] valueForKey:@"cardNumber"];
    imageViewForCard.image = [UIImage imageNamed:[[self.cardItems objectAtIndex:(NSUInteger) index] valueForKey:@"cardType"]];
    
    if(isCaraouselViewSelected == 0)
    {
        if(index == self.cardItems.count-1)
        {
            [imageViewForSlider setHidden:NO];
        }else{
            [imageViewForSlider setHidden:YES];
        }
    }else
    {
        if(imageViewForSlider.hidden == NO)
            imageViewForSlider.hidden = YES;
        else if(imageViewForSlider.hidden == YES)
            imageViewForSlider.hidden = NO;
    }
    
    view.tag = (int) index;
    imageViewForCard.tag = (int) index;
    label.tag = (int) index;
    imageViewForSlider.tag = (int) index;
    
    return view;
}

- (NSInteger)numberOfPlaceholdersInCarousel:(__unused iCarousel *)carousel
{
    //note: placeholder views are only displayed on some carousels if wrapping is disabled
    return 2;
}

- (UIView *)carousel:(__unused iCarousel *)carousel placeholderViewAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    UILabel *label = nil;
    UIImageView *imageViewForCard = nil;
    UIImageView *imageViewForSlider = nil;
    
    //create new view if no view is available for recycling
    if (view == nil)
    {
        //don't do anything specific to the index within
        //this `if (view == nil) {...}` statement because the view will be
        //recycled and used with other index values later
        
        view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 119.0f,80.0f)];
        view.backgroundColor = [UIColor clearColor];
        
        imageViewForCard = [[UIImageView alloc] initWithFrame:CGRectMake(19, 0, 80.0f, 54.0f)];
        imageViewForCard.backgroundColor = [UIColor clearColor];
        
        label = [[UILabel alloc] initWithFrame:CGRectMake(0, 57, 119.0f, 14.0f)];
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor whiteColor];
        [label setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:11]];
        
        
        imageViewForSlider = [[UIImageView alloc] initWithFrame:CGRectMake(0, 74, 119.0f, 6.0f)];
        imageViewForSlider.image = [UIImage imageNamed:@"img_cardselection.png"];
        imageViewForSlider.backgroundColor = [UIColor clearColor];
        
        [view addSubview:imageViewForCard];
        [view addSubview:imageViewForSlider];
        [view addSubview:label];
    }
    else
    {
        //get a reference to the label in the recycled view
        label = (UILabel *)[view viewWithTag:1];
        imageViewForCard = (UIImageView *) [view viewWithTag:1];
        imageViewForSlider = (UIImageView *) [view viewWithTag:1];
    }
    
    //set item label
    //remember to always set any properties of your carousel item
    //views outside of the `if (view == nil) {...}` check otherwise
    //you'll get weird issues with carousel item content appearing
    //in the wrong place in the carousel
    label.text = (index == 0)? @"[": @"]";
    imageViewForCard.image = [UIImage imageNamed:@"cardart_credit.png"];
    
    if(index == self.cardItems.count-1)
    {
        [imageViewForSlider setHidden:NO];
    }else{
        [imageViewForSlider setHidden:YES];
    }
    
    if(isCaraouselViewSelected == 0)
    {
        if(index == self.cardItems.count-1)
        {
            [imageViewForSlider setHidden:NO];
        }else{
            [imageViewForSlider setHidden:YES];
        }
    }else
    {
        if(imageViewForSlider.hidden == NO)
            imageViewForSlider.hidden = YES;
        else if(imageViewForSlider.hidden == YES)
            imageViewForSlider.hidden = NO;
    }
    
    
    view.tag = (int) index;
    imageViewForCard.tag = (int) index;
    label.tag = (int) index;
    imageViewForSlider.tag = (int) index;
    
    return view;
}

- (CATransform3D)carousel:(__unused iCarousel *)carousel itemTransformForOffset:(CGFloat)offset baseTransform:(CATransform3D)transform
{
    //implement 'flip3D' style carousel
    transform = CATransform3DRotate(transform, M_PI / 8.0f, 0.0f, 1.0f, 0.0f);
    return CATransform3DTranslate(transform, 0.0f, 0.0f, offset * self.carousel.itemWidth);
}

- (CGFloat)carousel:(__unused iCarousel *)carousel valueForOption:(iCarouselOption)option withDefault:(CGFloat)value
{
    //customize carousel display
    switch (option)
    {
        case iCarouselOptionWrap:
        {
            //normally you would hard-code this to YES or NO
            return YES;
        }
        case iCarouselOptionSpacing:
        {
            //add a bit of spacing between the item views
            return value * 1.0f;
        }
        case iCarouselOptionFadeMax:
        {
            if (self.carousel.type == iCarouselTypeCustom)
            {
                //set opacity based on distance from camera
                return 0.0f;
            }
            return value;
        }
        case iCarouselOptionShowBackfaces:
        case iCarouselOptionRadius:
        case iCarouselOptionAngle:
        case iCarouselOptionArc:
        case iCarouselOptionTilt:
        case iCarouselOptionCount:
        case iCarouselOptionFadeMin:
        case iCarouselOptionFadeMinAlpha:
        case iCarouselOptionFadeRange:
        case iCarouselOptionOffsetMultiplier:
        case iCarouselOptionVisibleItems:
        {
            return value;
        }
    }
}

#pragma mark -
#pragma mark iCarousel taps

- (void)carousel:(__unused iCarousel *)carouselView didSelectItemAtIndex:(NSInteger)index
{
    //int item = (int)index;
    //NSLog(@"Tapped view number: %d", item);
    
    selectedTag = index;
    isCaraouselViewSelected++;
    [carousel reloadItemAtIndex:lastSelectedIndex animated:NO];
    [carousel reloadItemAtIndex:index animated:NO];
    lastSelectedIndex = index;
}

- (void)carouselCurrentItemIndexDidChange:(__unused iCarousel *)carousel
{
    //NSLog(@"Index: %@", @(self.carousel.currentItemIndex));
}


#pragma mark - UITableView DataSource & Delegate Methods
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return paymentHistoryItems.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = 57.0;
    
    //Setting the height of the cell dynamically based on the height of the gifImage
    
    return  height;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    @try {
        
        static NSString *CellIdentifier = @"PayHistoryIdentifier";
        CustomCellForPayHistory *cell = (CustomCellForPayHistory *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil)
        {
            cell=[[CustomCellForPayHistory alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            NSArray *xib = [[NSBundle mainBundle] loadNibNamed:@"CustomCellForPayHistory" owner:self options:nil];
            cell = [xib objectAtIndex:0];
        }
        
        cell.labelForAmount.tag = indexPath.row;
        cell.labelForName.tag = indexPath.row;
        cell.labelForStatus.tag = indexPath.row;
        cell.labelForTime.tag = indexPath.row;
        
        TransactionData * data = [paymentHistoryItems objectAtIndex:indexPath.row];

        NSString *amount= [@"$" stringByAppendingString:[data.amount stringValue]];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        
        NSString *formattedDateString = [dateFormatter stringFromDate:data.date];
        NSLog(@"formattedDateString: %@", formattedDateString);
        
        cell.labelForName.text = [[data.fromName stringByAppendingString:@" paid "] stringByAppendingString:data.toName];
        cell.labelForAmount.text = amount;
        cell.labelForStatus.text = data.status;
        
        cell.labelForTime.text = formattedDateString;
        
        if(isCompleteTransaction)
        {
            if(indexPath.row == 0)
                cell.backgroundColor = [UIColor colorWithRed:103.0/255.0 green:182.0/255.0 blue:52.0/255.0 alpha:1];
            else
                cell.backgroundColor = [UIColor clearColor];
        }else
        {
            cell.backgroundColor = [UIColor clearColor];
        }
        
        return cell;
    }
    @catch (NSException *exception) {
    }
    @finally {
        
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}

#pragma mark - Motion Detection using Accelerometer & Gyroscope (Core Motion)
-(void)outputAccelertionData:(CMAcceleration)acceleration
{
    
    currentAccelX = acceleration.x;
    currentAccelY = acceleration.y;
    currentAccelZ = acceleration.z;
    
    
    
}
-(void)outputRotationData:(CMRotationRate)rotation
{
    currentRotX = rotation.x;
    currentRotY = rotation.y;
    currentRotZ = rotation.z;
    
    
}

#pragma mark - UITextField Delegate Methods
- (BOOL)textFieldShouldReturn:(UITextField *)theTextField
{
    [theTextField resignFirstResponder];
    return YES;
}

-(void)hideKeyboard:(UITapGestureRecognizer *)tap
{
    [self.textfieldToEnterAmount resignFirstResponder];
    CGRect frame = self.viewToEnterPayAmount.frame;
    self.viewToEnterPayAmount.frame = CGRectMake(frame.origin.x, 0.0, frame.size.width, frame.size.height);
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.35];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    [UIView commitAnimations];
}

-(void)cancelNumberPad
{
    [self.textfieldToEnterAmount resignFirstResponder];
    CGRect frame = self.viewToEnterPayAmount.frame;
    self.viewToEnterPayAmount.frame = CGRectMake(frame.origin.x, 0.0, frame.size.width, frame.size.height);
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.35];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    [UIView commitAnimations];
}

-(void)doneWithNumberPad
{
    [self.textfieldToEnterAmount resignFirstResponder];
    CGRect frame = self.viewToEnterPayAmount.frame;
    self.viewToEnterPayAmount.frame = CGRectMake(frame.origin.x, 0.0, frame.size.width, frame.size.height);
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.35];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    [UIView commitAnimations];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if(textField.keyboardType == UIKeyboardTypeDecimalPad) {
        
        CGRect frame = self.viewToEnterPayAmount.frame;
        
        self.viewToEnterPayAmount.frame = CGRectMake(frame.origin.x, frame.origin.y - 100, frame.size.width, frame.size.height);
        
        UIToolbar* numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
        numberToolbar.barStyle = UIBarStyleBlackTranslucent;
        numberToolbar.items = [NSArray arrayWithObjects:
                               [[UIBarButtonItem alloc]initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:self action:@selector(cancelNumberPad)],
                               [[UIBarButtonItem alloc]initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneWithNumberPad)],
                               nil];
        [numberToolbar sizeToFit];
        textField.inputAccessoryView = numberToolbar;
    }
    return YES;
}

#pragma mark - Button event methods

//Show all transactions
- (IBAction)fnForViewAllButtonPressed:(id)sender
{
    
}


-(IBAction)fnForDisappearButtonPressed:(id)sender
{
    
    if(viewToEnterPayAmount.hidden == NO)
    {
        [UIView animateWithDuration:0.3 animations:^{
            viewToEnterPayAmount.alpha = 0;
        } completion: ^(BOOL finished) {//creates a variable (BOOL) called "finished" that is set to *YES* when animation IS completed.
            viewToEnterPayAmount.hidden = finished;//if animation is finished ("finished" == *YES*), then hidden = "finished" ... (aka hidden = *YES*)
            isDetectedFace = NO;
        }];
    }else
    {
        [UIView animateWithDuration:0.3 animations:^{
            viewToAuthorisePayment.alpha = 0;
        } completion: ^(BOOL finished) {//creates a variable (BOOL) called "finished" that is set to *YES* when animation IS completed.
            viewToAuthorisePayment.hidden = finished;//if animation is finished ("finished" == *YES*), then hidden = "finished" ... (aka hidden = *YES*)
        }];
    }
    
}

-(IBAction)fnForTryAgainBtnPressed:(id)sender
{
    [UIView animateWithDuration:0.3 animations:^{
        viewToEnterPayAmount.alpha = 0;
    } completion: ^(BOOL finished) {//creates a variable (BOOL) called "finished" that is set to *YES* when animation IS completed.
        viewToEnterPayAmount.hidden = finished;//if animation is finished ("finished" == *YES*), then hidden = "finished" ... (aka hidden = *YES*)
        isDetectedFace = NO;
        [self setupAVCapture];
    }];
}

-(IBAction)fnForNextBtnPressed:(id)sender
{
    
    if(self.textfieldToEnterAmount.text.length >0)
    {
        BOOL isValidAmountMatch = [self checkRegexValidity:self.textfieldToEnterAmount.text regexPattern:@"[0-9]+([,.][0-9]{1,2})?"];
        if(isValidAmountMatch)
        {
            [UIView animateWithDuration:0.3 animations:^{
                viewToEnterPayAmount.alpha = 0;
            } completion: ^(BOOL finished) {//creates a variable (BOOL) called "finished" that is set to *YES* when animation IS completed.
                viewToEnterPayAmount.hidden = finished;//if animation is finished ("finished" == *YES*), then hidden = "finished" ... (aka hidden = *YES*)
                self.viewToAuthorisePayment.alpha = 0;
                self.viewToAuthorisePayment.hidden = NO;
                [UIView animateWithDuration:0.3 animations:^{
                    self.viewToAuthorisePayment.alpha = 1;
                    self.labelForPersonToPay.text = payToReceiver;
                    self.labelToDisplayAmount.text = self.textfieldToEnterAmount.text;
                    
                    [self.imageViewForDetectedPerson sd_setImageWithURL:[NSURL URLWithString:imageURL] placeholderImage:[UIImage imageNamed:@"profilePic_placeholder.png"]];
                    self.imageViewForDetectedPerson.layer.cornerRadius = self.imageViewForDetectedPerson.frame.size.width / 2;
                    self.imageViewForDetectedPerson.clipsToBounds = YES;
                    self.imageViewForDetectedPerson.layer.borderWidth = 2.0f;
                    self.imageViewForDetectedPerson.layer.borderColor = [UIColor whiteColor].CGColor;
                }];
            }];
        }else
        {
            [self showAlertMessage:@"The entered amount is invalid!" alertViewTitle:@"Error"];
            [self.textfieldToEnterAmount becomeFirstResponder];
        }
    }else
    {
        [self showAlertMessage:@"Please enter an amount!" alertViewTitle:@"Error"];
        [self.textfieldToEnterAmount becomeFirstResponder];
    }
}

-(IBAction)fnForBackBtnPressed:(id)sender
{
    [UIView animateWithDuration:0.3 animations:^{
        viewToAuthorisePayment.alpha = 0;
    } completion: ^(BOOL finished) {//creates a variable (BOOL) called "finished" that is set to *YES* when animation IS completed.
        viewToAuthorisePayment.hidden = finished;//if animation is finished ("finished" == *YES*), then hidden = "finished" ... (aka hidden = *YES*)
        self.viewToEnterPayAmount.alpha = 0;
        self.viewToEnterPayAmount.hidden = NO;
        [UIView animateWithDuration:0.3 animations:^{
            self.viewToEnterPayAmount.alpha = 1;
            self.labelForPersonDetected.text = receiverDetected;
            
            [self.imageViewForDetectedImage sd_setImageWithURL:[NSURL URLWithString:imageURL] placeholderImage:[UIImage imageNamed:@"profilePic_placeholder.png"]];
        }];
    }];
}

-(IBAction)fnForWinkToPayBtnPressed:(id)sender
{
    [UIView animateWithDuration:0.3 animations:^{
        viewToAuthorisePayment.alpha = 0;
    } completion: ^(BOOL finished) {//creates a variable (BOOL) called "finished" that is set to *YES* when animation IS completed.
        viewToAuthorisePayment.hidden = finished;//if animation is finished ("finished" == *YES*), then hidden = "finished" ... (aka hidden = *YES*)
        isDetectedFace = NO;
        self.viewForCarousel.hidden = YES;
        self.labelForGuidelines1.hidden = YES;
        self.labelForGuidelines.text = @"Wink to authorize payment!";
        self.isUsingFrontFacingCamera = YES;
        [self teardownAVCapture];
        [self setupAVCapture];
        //[self fnToToggleCameraView];
        
    }];
    
}

// main action method to take a still image -- if face detection has been turned on and a face has been detected
// the square overlay will be composited on top of the captured image and saved to the camera roll
-(IBAction)fnForCaptureButtonPressed:(id)sender
{
    [self fnToCaptureStillImage];
}

#pragma mark - View lifecycle
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        [self setUpCardData];
        [self setUpPaymentHistoryData];
        
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUpCardData];
        [self setUpPaymentHistoryData];
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.activityIndicatorView.hidden = YES;
    [self.activityIndicatorView stopAnimating];
    
    imageURL = @"";
    self.imageViewForArrow.image = [UIImage imageNamed:@"img_uparrow.png"];
    isDetectedFace = NO;
    
    self.faceOutlineImage = [UIImage imageNamed:@"img_dottedface"];
    
    //Caraousel initial settings
    self.carousel.type = iCarouselTypeLinear;
    self.carousel.vertical = NO;
    
    self.isUsingFrontFacingCamera = NO;
    self.isCompleteTransaction = NO;
    
    [self setupAVCapture];
    
    NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyHigh, CIDetectorAccuracy, nil];
    self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    
    [self fnToSetupMotionDetection];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [self teardownAVCapture];
    self.faceDetector = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard:)];
    [gesture setNumberOfTapsRequired:1];
    [gesture setNumberOfTouchesRequired:1];
    [self.viewToEnterPayAmount addGestureRecognizer:gesture];
    
    isCaraouselViewSelected =0;
    lastSelectedIndex = cardItems.count - 1;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self hideActivityIndicator];
    isCaraouselViewSelected =0;
    lastSelectedIndex = cardItems.count - 1;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Gesture Recognizer methods

//Handel swipe gesture to chek the direction and pull the carousel voiew
- (IBAction)fnForhandleSwipeUpDownMovement:(id) sender
{
    viewFrame = self.viewForCarousel.frame;
    if (viewFrame.origin.y == 553.0)
    {
        
        viewFrame.origin.y = [[UIScreen mainScreen] bounds].size.height - self.viewForCarousel.frame.size.height;
        
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations:^
         {
             self.viewForCarousel.frame = viewFrame;
             self.imageViewForArrow.image = [UIImage imageNamed:@"img_downarrow"];
         }
                         completion:^(BOOL finished)
         {
         }];
        
    }else
    {
        viewFrame.origin.y = 553.0;
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations:^
         {
             self.viewForCarousel.frame = viewFrame;
             self.imageViewForArrow.image = [UIImage imageNamed:@"img_uparrow"];
         }
                         completion:^(BOOL finished)
         {
         }];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ( [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] ) {
        beginGestureScale = effectiveScale;
    }else if ([gestureRecognizer isKindOfClass:[UISwipeGestureRecognizer class]])
    {
        //Do something here where the carousel view with history needs to be pulled up/down respectively
    }
    return YES;
}

// scale image depending on users pinch gesture
- (IBAction)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer
{
    BOOL allTouchesAreOnThePreviewLayer = YES;
    NSUInteger numTouches = [recognizer numberOfTouches], i;
    for ( i = 0; i < numTouches; ++i ) {
        CGPoint location = [recognizer locationOfTouch:i inView:self.previewView];
        CGPoint convertedLocation = [self.previewLayer convertPoint:location fromLayer:self.previewLayer.superlayer];
        if ( ! [self.previewLayer containsPoint:convertedLocation] ) {
            allTouchesAreOnThePreviewLayer = NO;
            break;
        }
    }
    
    if ( allTouchesAreOnThePreviewLayer ) {
        effectiveScale = beginGestureScale * recognizer.scale;
        if (effectiveScale < 1.0)
            effectiveScale = 1.0;
        CGFloat maxScaleAndCropFactor = [[self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
        if (effectiveScale > maxScaleAndCropFactor)
            effectiveScale = maxScaleAndCropFactor;
        [CATransaction begin];
        [CATransaction setAnimationDuration:.025];
        [self.previewLayer setAffineTransform:CGAffineTransformMakeScale(effectiveScale, effectiveScale)];
        [CATransaction commit];
    }
}

#pragma mark - Face Recognition Using Kairo SDK
- (void) fnToRecognizeFacesUsingKairo: (UIImage *) inputImage threshold:(NSString *) threshold galleryName:(NSString *) galleryName
{
    
    @try {
        [KairosSDK recognizeWithImage:inputImage
                            threshold:threshold
                          galleryName:galleryName
                           maxResults:@"10"
                              success:^(NSDictionary *response) {
                                  
                                  NSLog(@"%@", response);
                                  [self hideActivityIndicator];
                                  
                                  NSString * status = [[[[response objectForKey:@"images"] objectAtIndex:0] objectForKey:@"transaction"] objectForKey:@"status"];
                                  
                                  if([status isEqualToString:@"success"])
                                  {
                                      
                                      NSString * userID = [[[[response objectForKey:@"images"] objectAtIndex:0] objectForKey:@"transaction"] objectForKey:@"subject"];
                                      
                                      NSLog(@"User id: %@",userID);
                                  
                                      //Front facing camera authorising with selfie
                                      if(self.isUsingFrontFacingCamera)
                                      {
                                          if([userID isEqualToString:personData.personId])
                                          {
                                              TransactionData *transactionData = [[TransactionData alloc] initWithTransactionID:[self randomAlphanumericStringWithLength:8] fromName:[[personData.firstName stringByAppendingString:@" "] stringByAppendingString:personData.lastName] toName:receiverName amount:[NSNumber numberWithInt:[self.labelToDisplayAmount.text intValue]] status:@"Completed" date:[NSDate date]];
                                              
                                              isCompleteTransaction = NO;
                                              
                                              PFObject *transaction = [PFObject objectWithClassName:@"Transaction"];
                                              transaction[@"from"] = transactionData.fromName;
                                              transaction[@"to"] = transactionData.toName;
                                              transaction[@"status"] = transactionData.status;
                                              transaction[@"amount"] = transactionData.amount;
                                              transaction[@"transactionDate"] = transactionData.date;
                                              transaction[@"transactionID"] = transactionData.transactionID;

                                              [transaction saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                                                  if (succeeded) {
                                                      // The object has been saved.
                                                      
                                                      self.viewForPaymentConfirmation.alpha = 0;
                                                      self.viewForPaymentConfirmation.hidden = NO;
                                                      self.imageViewForOutline.image = [UIImage imageNamed:@"img_dottedface.png"];
                                                      
                                                      self.imageViewForArrow.image = [UIImage imageNamed:@"img_uparrow.png"];
                                                      [UIView animateWithDuration:0.3 animations:^{
                                                          self.viewForPaymentConfirmation.alpha = 1;
                                                          
                                                          [self performSelector:@selector(showRecentTransaction)
                                                                     withObject:nil
                                                                     afterDelay:3.0];
                                                          
                                                      }];

                                                  } else {
                                                      // There was a problem, check error.description
                                                      [self showAlertMessage:@"Payment did not go through! Try again" alertViewTitle:@"Transaction Error"];
                                                  }
                                              }];
                                              
                                              
                                          }else
                                          {
                                              
                                              [self showAlertMessage:@"Sender incorrectly authorised! Try again" alertViewTitle:@"Authorisation error"];
                                              isDetectedFace = NO;
                                              [self setupAVCapture];
                                              
                                          }
                                          
                                      }else
                                      {
                                          //Back facing camera for receiver authorisation
                                          NSString *name=@"";
                                          for (NSDictionary *dictionary in self.friendsList) {
                                              
                                              if([[dictionary objectForKey:@"id"] isEqualToString:userID])
                                              {
                                                  receiverName = [dictionary objectForKey:@"name"];
                                                  
                                                  NSArray *fullname = [[ dictionary objectForKey:@"name"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                                                  
                                                  name = [fullname objectAtIndex:0];
                                                  
                                                  receiverDetected = [NSString stringWithFormat:@"%@",name];
                                                  payToReceiver = [NSString stringWithFormat:@"You will pay %@",name];
                                                  
                                                  
                                                  FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc]
                                                                                initWithGraphPath:userID
                                                                                parameters:@{ @"fields" : @"id,name,picture.width(120).height(100)"}
                                                                                HTTPMethod:@"GET"];
                                                  [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection,
                                                                                        id result,
                                                                                        NSError *error) {
                                                      if(!error)
                                                      {
                                                          
                                                          // Handle the result
                                                          NSString *imageURLString = [[[result objectForKey:@"picture"] objectForKey:@"data"] objectForKey:@"url"];
                                                          
                                                          self.imageViewForOutline.image = [UIImage imageNamed:@"img_dottedface.png"];
                                                          self.viewToEnterPayAmount.alpha = 0;
                                                          self.viewToEnterPayAmount.hidden = NO;
                                                          [UIView animateWithDuration:0.3 animations:^{
                                                              self.viewToEnterPayAmount.alpha = 1;
                                                              self.labelForPersonDetected.text = receiverDetected;
                                                              
                                                              [self.imageViewForDetectedImage sd_setImageWithURL:[NSURL URLWithString:imageURLString] placeholderImage:[UIImage imageNamed:@"profilePic_placeholder.png"]];
                                                              
                                                              imageURL = imageURLString;
                                                              
                                                              self.imageViewForDetectedImage.layer.cornerRadius = self.imageViewForDetectedImage.frame.size.width / 2;
                                                              self.imageViewForDetectedImage.clipsToBounds = YES;
                                                              self.imageViewForDetectedImage.layer.borderWidth = 2.0f;
                                                              self.imageViewForDetectedImage.layer.borderColor = [UIColor whiteColor].CGColor;
                                                              
                                                          }];

                                                      }else
                                                      {
                                                          [self showAlertMessage:@"Something went wrong! Please try again" alertViewTitle:@"Error"];
                                                      }
                                                      
                                                  }];
                                                  break;
                                              }
                                          }

                                          if(imageURL.length ==0 && name.length == 0)
                                          {
                                              [self showAlertMessage:@"The user is not your FB friend. Please add him/her as your payment friend!" alertViewTitle:@"Error"];
                                              isDetectedFace = NO;
                                              [self setupAVCapture];
                                          }
                                      }
                                  }else
                                  {
                                      [self hideActivityIndicator];
                                      
                                      if(self.isUsingFrontFacingCamera)
                                      {
                                          
                                          [self showAlertMessage:@"Sender incorrectly authorised! Try again" alertViewTitle:@"Authorisation error"];
                                      }else
                                      {
                                          
                                          [self showAlertMessage:@"No match found! Please register!" alertViewTitle:@"Authorisation error"];
                                      }
                                      isDetectedFace = NO;
                                      
                                      [self setupAVCapture];
                                  }
                              }
                              failure:^(NSDictionary *response) {
                                  
                                  [self hideActivityIndicator];
                                  
                                  [self showAlertMessage:@"No match found! Please register!" alertViewTitle:@"Authorisation error"];
                                  
                                  [self setupAVCapture];
                              }];
    }
    @catch (NSException *exception) {
        //NSLog(@"Exception: %@",exception.reason);
    }
    @finally {
        
    }
}

#pragma mark - Custom Methods
- (NSString *)randomAlphanumericStringWithLength:(NSInteger)length
{
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:length];
    
    for (int i = 0; i < length; i++) {
        [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random() % [letters length]]];
    }
    
    return randomString;
}


- (void) fnToCaptureStillImage
{
    @try {
        // Find out the current orientation and tell the still image output.
        AVCaptureConnection *stillImageConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
        AVCaptureVideoOrientation avcaptureOrientation = [self avOrientationForDeviceOrientation:curDeviceOrientation];
        [stillImageConnection setVideoOrientation:avcaptureOrientation];
        [stillImageConnection setVideoScaleAndCropFactor:1.0];
        
        BOOL doingFaceDetection = YES;
        
        // set the appropriate pixel format / image type output setting depending on if we'll need an uncompressed image for
        // the possiblity of drawing the red square over top or if we're just writing a jpeg to the camera roll which is the trival case
        if (doingFaceDetection)
            [self.stillImageOutput setOutputSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                                                                                 forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        else
            [self.stillImageOutput setOutputSettings:[NSDictionary dictionaryWithObject:AVVideoCodecJPEG
                                                                                 forKey:AVVideoCodecKey]];
        
        [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
                                                           completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                                               if (error) {
                                                                   [self displayErrorOnMainQueue:error withMessage:@"Take picture failed"];
                                                               }
                                                               else {
                                                                   if (doingFaceDetection) {
                                                                       
                                                                       NSDictionary *imageOptions = nil;
                                                                       NSNumber *orientation = (__bridge NSNumber *)(CMGetAttachment(imageDataSampleBuffer, kCGImagePropertyOrientation, NULL));
                                                                       if (orientation) {
                                                                           imageOptions = [NSDictionary dictionaryWithObject:orientation forKey:CIDetectorImageOrientation];
                                                                       }
                                                                       
                                                                       CGImageRef srcImage = NULL;
                                                                       OSStatus err = CreateCGImageFromCVPixelBuffer(CMSampleBufferGetImageBuffer(imageDataSampleBuffer), &srcImage);
                                                                       check(!err);
                                                                       
                                                                       
                                                                       CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                                                                                                   imageDataSampleBuffer,
                                                                                                                                   kCMAttachmentMode_ShouldPropagate);
                                                                       
                                                                       if (attachments)
                                                                           CFRelease(attachments);
                                                                       
                                                                       CGFloat rotationDegrees = 90.;
                                                                       
                                                                       UIImage *imageForPersonDetected = [[UIImage alloc] initWithCGImage:srcImage];
                                                                       imageForPersonDetected = [imageForPersonDetected imageRotatedByDegrees:rotationDegrees];
                                                                       
                                                                       if (srcImage)
                                                                           CFRelease(srcImage);
                                                                       
                                                                       self.activityIndicatorView.hidden = NO;
                                                                       [self.activityIndicatorView startAnimating];
                                                                       
                                                                       [self fnToRecognizeFacesUsingKairo:imageForPersonDetected threshold:@"0.75" galleryName:@"WinkToPayFinal"];
                                                                       
                                                                   }
                                                                   
                                                               }
                                                           }
         ];
        
    }
    @catch (NSException *exception) {
        //NSLog(@"Exception: %@",exception.reason);
    }
    @finally {
        
    }
    
}


// use front/back camera might have to remove
- (void)fnToToggleCameraView
{
    AVCaptureDevicePosition desiredPosition;
    if (self.isUsingFrontFacingCamera)
        desiredPosition = AVCaptureDevicePositionFront;
    else
        desiredPosition = AVCaptureDevicePositionBack;
    
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([d position] == desiredPosition) {
            [[self.previewLayer session] beginConfiguration];
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:d error:nil];
            for (AVCaptureInput *oldInput in [[self.previewLayer session] inputs]) {
                [[self.previewLayer session] removeInput:oldInput];
            }
            [[self.previewLayer session] addInput:input];
            [[self.previewLayer session] commitConfiguration];
            break;
        }
    }
}


-(void) fnToSetupMotionDetection
{
    currentAccelX = 0;
    currentAccelY = 0;
    currentAccelZ = 0;
    
    currentRotX = 0;
    currentRotY = 0;
    currentRotZ = 0;
    
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.accelerometerUpdateInterval = .2;
    self.motionManager.gyroUpdateInterval = .2;
    
    [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue]
                                             withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
                                                 [self outputAccelertionData:accelerometerData.acceleration];
                                                 if(error){
                                                     
                                                     //NSLog(@"%@", error);
                                                 }
                                             }];
    
    [self.motionManager startGyroUpdatesToQueue:[NSOperationQueue currentQueue]
                                    withHandler:^(CMGyroData *gyroData, NSError *error) {
                                        [self outputRotationData:gyroData.rotationRate];
                                        
                                        if(error)
                                        {
                                            //NSLog(@"%@", error);
                                            
                                        }
                                    }];
}

-(void) showAlertMessage:(NSString *)errMsg alertViewTitle:(NSString *)tiltle{
    
    if(alertView)
        alertView = nil;
    
    alertView=[[UIAlertView alloc]initWithTitle:tiltle message:errMsg delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alertView show];
}

- (void) hideActivityIndicator
{
    self.activityIndicatorView.hidden = YES;
    [self.activityIndicatorView stopAnimating];
}



-(BOOL) checkRegexValidity:(NSString *)emailID regexPattern:(NSString *) regex{
    BOOL isValid;
    NSPredicate * regextest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    
    isValid = [regextest evaluateWithObject:emailID];
    
    return isValid;
}


-(void) showRecentTransaction
{
    [UIView animateWithDuration:0.3 animations:^{
        viewForPaymentConfirmation.alpha = 0;
    } completion: ^(BOOL finished) {//creates a variable (BOOL) called "finished" that is set to *YES* when animation IS completed.
        
        self.viewForCarousel.hidden = NO;
        self.isUsingFrontFacingCamera = NO;
        [self setupAVCapture];
        //[self fnToToggleCameraView];
        
        self.viewForGuidlines.hidden = NO;
        self.labelForGuidelines.hidden = NO;
        self.labelForGuidelines.text = @"Keep your friend's face";
        self.labelForGuidelines1.hidden = NO;
        
        
        [self setUpPaymentHistoryData];
        isCompleteTransaction = YES;
        isDetectedFace = NO;
        viewForPaymentConfirmation.hidden = finished;//if animation is finished ("finished" == *YES*), then hidden = "finished" ... (aka hidden = *YES*)
        
    }];
    
    
    viewFrame = self.viewForCarousel.frame;
    if (viewFrame.origin.y == 553.0)
    {
        
        viewFrame.origin.y = [[UIScreen mainScreen] bounds].size.height - self.viewForCarousel.frame.size.height;
        
        [UIView animateWithDuration:0.6
                              delay:0.0
                            options: UIViewAnimationOptionCurveEaseInOut
                         animations:^
         {
             self.viewForCarousel.frame = viewFrame;
             self.imageViewForArrow.image = [UIImage imageNamed:@"img_downarrow.png"];
         }
                         completion:^(BOOL finished)
         {
         }];
    }
}

- (void) setUpCardData
{
    //Card Model Setup
    cardItems = [[NSMutableArray alloc] init];
    
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    [dictionary setValue:@"cardart_debit.png" forKey:@"cardType"];
    [dictionary setValue:@"Visa Debit...1234" forKey:@"cardNumber"];
    [cardItems addObject:dictionary];
    
    dictionary = [[NSMutableDictionary alloc] init];
    [dictionary setValue:@"cardart_credit.png" forKey:@"cardType"];
    [dictionary setValue:@"Visa Credit...5678" forKey:@"cardNumber"];
    [cardItems addObject:dictionary];
    
    
    dictionary = [[NSMutableDictionary alloc] init];
    [dictionary setValue:@"cardart_prepaid.png" forKey:@"cardType"];
    [dictionary setValue:@"Visa Pre...9012" forKey:@"cardNumber"];
    [cardItems addObject:dictionary];
    
    dictionary = nil;
}

- (void) setUpPaymentHistoryData
{
    paymentHistoryItems = [[NSMutableArray alloc] init];
    
    PFQuery *query = [PFQuery queryWithClassName:@"Transaction"];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            NSLog(@"Transaction Data: %@",objects);
            NSArray* reversedArray = [[objects reverseObjectEnumerator] allObjects];
            
            for (PFObject *object in reversedArray) {
                NSLog(@"%@", object.objectId);
                
                NSString * from = @"";
                NSString * to = @"";
                NSArray *fromFullname = [[object objectForKey:@"from"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSArray *toFullname = [[object objectForKey:@"to"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                
                if([[fromFullname objectAtIndex:0] isEqualToString:personData.firstName])
                {
                    from = @"You";
                }else
                {
                    from = [fromFullname objectAtIndex:0];
                }
                
                if([[toFullname objectAtIndex:0] isEqualToString:personData.firstName])
                {
                    to = @"you";
                }else
                {
                    to = [toFullname objectAtIndex:0];
                }
                
                
                TransactionData *transactionData = [[TransactionData alloc] initWithTransactionID:[object objectForKey:@"transactionID"] fromName:from toName:to amount:[object objectForKey:@"amount"] status:[object objectForKey:@"status"] date:[object objectForKey:@"transactionDate"]];
                
                [paymentHistoryItems addObject:transactionData];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^ {
                [self.tableViewForPayHistory reloadData];
            });
            
        } else {
            // Log details of the failure
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
}



@end





