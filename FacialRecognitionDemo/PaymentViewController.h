//
//  PaymentViewController.h
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/23/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface PaymentViewController : UIViewController
{
}

-(IBAction)fnForConfirmPayButtonPressed:(id)sender;
@property (strong,nonatomic) UIImage  *croppedImage;
@property (weak,nonatomic)IBOutlet  UIImageView *imageViewForRecProfile;
@property (weak,nonatomic)IBOutlet  UILabel *labelForDetectedPerson;
@property (strong,nonatomic) NSString *personDetected;


@end
