//
//  CameraViewController.h
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/26/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "iCarousel.h"
#import "CustomCellForPayHistory.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMotion/CoreMotion.h>
#import "PersonData.h"
#import "TransactionData.h"

@class CIDetector;

@interface CameraViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate,iCarouselDataSource, iCarouselDelegate,UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate,UIScrollViewDelegate>
{
    
    UIView *flashView;
    
    BOOL isCompleteTransaction;
    BOOL isDetectedFace;
    
    
    CGFloat beginGestureScale;
    CGFloat effectiveScale;
    
    NSString *receiverDetected;
    NSString *payToReceiver;
    
    CGRect viewFrame;
    
    UIAlertView *alertView;
    
    NSInteger isCaraouselViewSelected;
    NSInteger lastSelectedIndex;
    NSInteger selectedTag;
    
    double currentAccelX;
    double currentAccelY;
    double currentAccelZ;
    double currentRotX;
    double currentRotY;
    double currentRotZ;
    
    NSString *imageURL;
    NSString *receiverName;
}

//Initialise with the person model
- (id) initWithPersonData:(PersonData *) persondata friendslist:(NSMutableArray *) friendslist;

//Camera View Controller
@property (weak,nonatomic) IBOutlet UIView * previewView;
@property (nonatomic,strong) PersonData *personData;
@property (nonatomic,strong) NSMutableArray *friendsList;
@property (assign,nonatomic) BOOL isCompleteTransaction;
@property (assign,nonatomic) BOOL isDetectedFace;
@property (weak,nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic,weak) IBOutlet UIImageView *imageViewForOutline;


-(IBAction)fnForCaptureButtonPressed:(id)sender;
- (IBAction)handlePinchGesture:(UIGestureRecognizer *)sender;


//Location Updates using Core Motion
@property (strong, nonatomic) CMMotionManager *motionManager;



//Guidelines View
@property (weak,nonatomic) IBOutlet UIView *viewForGuidlines;
@property (weak,nonatomic) IBOutlet UILabel *labelForGuidelines;
@property (weak,nonatomic) IBOutlet UILabel *labelForGuidelines1;


//Carousel View & History View
@property (nonatomic, weak) IBOutlet iCarousel *carousel;
@property (nonatomic,weak) IBOutlet UIView *viewForCarousel;
@property (nonatomic,weak) IBOutlet UIImageView *imageViewForArrow;
- (IBAction)fnForhandleSwipeUpDownMovement:(id)sender;
@property (weak,nonatomic) IBOutlet UITableView *tableViewForPayHistory;
@property (nonatomic, strong) NSMutableArray *cardItems;
@property (nonatomic, strong) NSMutableArray *paymentHistoryItems;
- (IBAction)fnForViewAllButtonPressed:(id)sender;





//Popup View
-(IBAction)fnForDisappearButtonPressed:(id)sender;

//Payment View Controller
@property (weak,nonatomic) IBOutlet UIView *viewToEnterPayAmount;
@property (weak,nonatomic) IBOutlet UIView *viewToAuthorisePayment;

@property (weak,nonatomic) IBOutlet UIImageView *imageViewForDetectedImage;
@property (weak,nonatomic)IBOutlet UIImageView *imageViewForDetectedPerson;

@property (weak,nonatomic) IBOutlet UITextField *textfieldToEnterAmount;

@property (weak,nonatomic) IBOutlet UILabel *labelToDisplayAmount;
@property (weak,nonatomic) IBOutlet UILabel *labelForPersonToPay;
@property (weak,nonatomic) IBOutlet UILabel *labelForPersonDetected;

-(IBAction)fnForTryAgainBtnPressed:(id)sender;
-(IBAction)fnForNextBtnPressed:(id)sender;
-(IBAction)fnForBackBtnPressed:(id)sender;
-(IBAction)fnForWinkToPayBtnPressed:(id)sender;

//Payment Receipt View
@property (weak,nonatomic) IBOutlet UIView *viewForPaymentConfirmation;









@end
