//
//  Person.m
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 6/23/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import "PersonData.h"

@implementation PersonData

@synthesize personId = _personId, firstName = _firstName, lastName = _lastName, emailId = _emailId, cardNumber= _cardNumber, cardType = _cardType, cVV = _cVV;


- (id) initWithPersonID :(NSString *)personId firstName:(NSString *)firstName lastName:(NSString *)lastName emailId:(NSString *)emailId cardNumber:(NSInteger) cardNumber cardType:(NSString *)cardType cVV:(NSInteger) cVV
{
    if ((self = [super init])) {
        self.personId = personId;
        self.firstName = firstName;
        self.lastName = lastName;
        self.emailId = emailId;
        self.cardNumber = cardNumber;
        self.cardType = cardType;
        self.cVV = cVV;
    }
    return self;
}


@end
