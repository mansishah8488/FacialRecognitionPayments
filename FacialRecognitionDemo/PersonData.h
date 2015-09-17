//
//  Person.h
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/23/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PersonData : NSObject
{
    NSString *_personId;
    NSString *_firstName;
    NSString *_lastName;
    NSString *_emailId;
    NSInteger _cardNumber;
    NSString *_cardType;
    NSInteger _cVV;
}

@property (nonatomic, strong) NSString *personId;
@property (nonatomic, strong) NSString *firstName;
@property (nonatomic, strong) NSString *lastName;
@property (nonatomic, strong) NSString *emailId;
@property (nonatomic, assign) NSInteger cardNumber;
@property (nonatomic, strong) NSString *cardType;
@property (nonatomic,assign) NSInteger cVV;


- (id) initWithPersonID :(NSString *)personId firstName:(NSString *)firstName lastName:(NSString *)lastName emailId:(NSString *)emailId cardNumber:(NSInteger) cardNumber cardType:(NSString *)cardType cVV:(NSInteger) cVV;

@end
