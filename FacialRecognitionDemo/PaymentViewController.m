//
//  PaymentViewController.m
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/23/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import "PaymentViewController.h"

@interface PaymentViewController ()

@end

@implementation PaymentViewController
@synthesize croppedImage,imageViewForRecProfile,personDetected;
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    if(croppedImage)
    {
        imageViewForRecProfile.image = croppedImage;
    }
    
    if(personDetected)
    {
        self.labelForDetectedPerson.text = personDetected;
    }
        
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Button Press Event functions
-(IBAction)fnForConfirmPayButtonPressed:(id)sender
{
    //cameraviewController = [[self.navigationController viewControllers] objectAtIndex:2];
    //cameraviewController.isUsingFrontFacingCamera = YES;
    
    [self.navigationController popViewControllerAnimated:YES];
}


@end
