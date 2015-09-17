//
//  ConfirmationViewController.m
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/23/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import "ConfirmationViewController.h"

@interface ConfirmationViewController ()

@end

@implementation ConfirmationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self performSelector:@selector(showHistoryView) withObject:nil afterDelay:4];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) showHistoryView
{
    [self.navigationController popToViewController: [self.navigationController.viewControllers objectAtIndex:1] animated:YES];
}


@end
