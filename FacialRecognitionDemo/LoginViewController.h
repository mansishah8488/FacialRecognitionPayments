//
//  LoginViewController.h
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 7/21/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CameraViewController.h"
#import "PersonData.h"

@interface LoginViewController : UIViewController
{
    
}

- (IBAction)fnForFBLoginButtonPressed:(id)sender;
@property (nonatomic,strong) CameraViewController *cameraViewController;

@end
