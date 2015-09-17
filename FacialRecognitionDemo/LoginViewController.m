//
//  LoginViewController.m
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 7/21/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import "LoginViewController.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>

@interface LoginViewController ()

@end

@implementation LoginViewController
@synthesize cameraViewController;
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)fnForFBLoginButtonPressed:(id)sender
{
    FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];
    [login logInWithReadPermissions:@[@"public_profile", @"email", @"user_friends", @"user_photos"] handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (error) {
            // Process error
            NSLog(@"Error: %@",error.localizedDescription);
            
        } else if (result.isCancelled) {
            // Handle cancellations
            
        } else {
            
            NSLog(@"User ID: %@",result.token.userID);

            // If you ask for multiple permissions at once, you
            // should check if specific permissions missing
            if ([result.grantedPermissions containsObject:@"email"] && [result.grantedPermissions containsObject:@"public_profile"] && [result.grantedPermissions containsObject:@"user_friends"]) {
                
                //Fetch the user information
                [[[FBSDKGraphRequest alloc] initWithGraphPath:@"me" parameters:@{ @"fields" : @"id,name,email,picture.width(120).height(120)"}]
                 startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
                     //Handle the fetched user result
                     if (!error) {
                         NSLog(@"fetched user:%@", result);
                         NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                         [defaults setObject:[result objectForKey:@"id"]  forKey:@"id"];
                         
                         NSArray *name = [[result objectForKey:@"name"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                         
                         PersonData *personData = [[PersonData alloc] initWithPersonID:[result objectForKey:@"id"]  firstName:[name objectAtIndex:0] lastName:[name objectAtIndex:1] emailId:[result objectForKey:@"email"] cardNumber:1234567890 cardType:@"visa" cVV:123];
                         
                         //Fetch friends
                         FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc]
                                                       initWithGraphPath:@"me/friends"
                                                       parameters:@{ @"fields" : @"id,name"}
                                                       HTTPMethod:@"GET"];
                         [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection,
                                                               id result,
                                                               NSError *error) {
                             // Handle the friends list result
                             if(!error)
                             {
                                 NSMutableArray *friendsList = [[NSMutableArray alloc] init];
                                 friendsList = [result objectForKey:@"data"];
                                 self.cameraViewController = [[CameraViewController alloc] initWithPersonData:personData friendslist:friendsList];
                                 [self.navigationController pushViewController:self.cameraViewController animated:YES];
                                 
                             }else
                             {
                                 NSLog(@"Fetch friend list error: %@",error.localizedDescription);
                             }
                             
                         }];
 
                     }else
                     {
                         NSLog(@"Fetch user error %@",error.localizedDescription);
                     }
                 }];
            }
        }
    }];
}


@end
