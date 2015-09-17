//
//  CustomCellForPayHistory.h
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/23/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CustomCellForPayHistory : UITableViewCell
{
    
}

@property (weak, nonatomic) IBOutlet UILabel *labelForName;
@property (weak, nonatomic) IBOutlet UILabel *labelForAmount;
@property (weak, nonatomic) IBOutlet UILabel *labelForStatus;
@property (weak, nonatomic) IBOutlet UILabel *labelForTime;


@property (weak, nonatomic) IBOutlet UIView *viewForSeperator;

@end
