//
//  HistoryViewController.h
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/22/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CustomCellForPayHistory.h"
#import "CameraViewController.h"
#define DETECT_IMAGE_MAX_SIZE  640


@interface HistoryViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>
{
    CameraViewController *cameraViewController;
}

@property (weak,nonatomic) IBOutlet UITableView *tableViewForPayHistory;

-(IBAction)fnForPayButtonPressed:(id)sender;


@end
