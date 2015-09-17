//
//  AppDelegate.m
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/22/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import "AppDelegate.h"
#import "KairosSDK.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <Parse/Parse.h>

@interface AppDelegate ()


@end

@implementation AppDelegate
@synthesize navigationController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    [KairosSDK initWithAppId:@"ede11f79" appKey:@"fa96e8705dacc541d756b1ecb9f48d0e"];
    
    
    // Initialize Parse.
    [Parse setApplicationId:@"YAtG8EH8DFGqychzRs4pl6trJ9vSij3clsLWbEiQ"
                  clientKey:@"FYRdsDxpIZuYISQGXdKUctp0A88UipppvISQan7o"];
    
    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
    
    [[FBSDKApplicationDelegate sharedInstance] application:application
                             didFinishLaunchingWithOptions:launchOptions];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    //Remember me functionality
    if ([FBSDKAccessToken currentAccessToken] || [defaults objectForKey:@"id"]) {
        
        [[[FBSDKGraphRequest alloc] initWithGraphPath:@"me" parameters:@{ @"fields" : @"id,name,email,picture.width(120).height(120)"}]
         startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
             if (!error) {
                 NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                 [defaults setObject:[result objectForKey:@"id"] forKey:@"id"];
                 
                 NSArray *name = [[result objectForKey:@"name"]  componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                 
                 PersonData *personData = [[PersonData alloc] initWithPersonID:[result objectForKey:@"id"] firstName:[name objectAtIndex:0] lastName:[name objectAtIndex:1] emailId:[result objectForKey:@"email"] cardNumber:1234567890 cardType:@"visa" cVV:123];
                 
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
                         //NSLog(@"Friend list:%@", result);
                         NSMutableArray *friendsList = [[NSMutableArray alloc] init];
                         friendsList = [result objectForKey:@"data"];
                         self.cameraViewController = [[CameraViewController alloc] initWithPersonData:personData friendslist:friendsList];
                         navigationController  = [[UINavigationController alloc] initWithRootViewController:self.cameraViewController];
                         [navigationController setNavigationBarHidden:YES];
                         self.window.rootViewController = navigationController;
                         [self.window makeKeyAndVisible];
                         
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
        
    }else
    {
        self.loginViewController = [[LoginViewController alloc] initWithNibName:@"LoginViewController" bundle:nil];
        navigationController  = [[UINavigationController alloc] initWithRootViewController:self.loginViewController];
        [navigationController setNavigationBarHidden:YES];
        self.window.rootViewController = navigationController;
        [self.window makeKeyAndVisible];

    }

    
    
    return YES;
}



- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                                          openURL:url
                                                sourceApplication:sourceApplication
                                                       annotation:annotation];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    [FBSDKAppEvents activateApp];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
