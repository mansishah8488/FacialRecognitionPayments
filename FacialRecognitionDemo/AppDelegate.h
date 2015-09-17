//
//  AppDelegate.h
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/22/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LoginViewController.h"
#import "CameraViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) LoginViewController *loginViewController;
@property (strong, nonatomic) UINavigationController *navigationController;
@property (strong, nonatomic) CameraViewController *cameraViewController;


@end

