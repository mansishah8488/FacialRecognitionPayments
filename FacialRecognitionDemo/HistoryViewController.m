//
//  HistoryViewController.m
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/22/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import "HistoryViewController.h"

@interface HistoryViewController ()

@end

@implementation HistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Custom Methods
-(void) showAlertMessage:(NSString *)errMsg alertViewTitle:(NSString *)tiltle{
    UIAlertView *errorAlertView=[[UIAlertView alloc]initWithTitle:tiltle message:errMsg delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [errorAlertView show];
}



#pragma mark - Button Pressed Event functions
-(IBAction)fnForPayButtonPressed:(id)sender
{
    //cameraViewController = [[CameraViewController alloc] init];
    //[self.navigationController pushViewController:cameraViewController animated:NO];
}


#pragma mark - UITableView DataSource & Delegate Methods
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 6;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = 59.0;
    
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
        return cell;
    }
    @catch (NSException *exception) {
    }
    @finally {
        
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Row selected");
}



@end
