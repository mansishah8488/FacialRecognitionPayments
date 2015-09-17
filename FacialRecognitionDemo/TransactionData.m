//
//  TransactionData.m
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 7/21/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import "TransactionData.h"

@implementation TransactionData

@synthesize  fromName =  _fromName, toName = _toName,  amount =_amount, status = _status, date = _date, transactionID = _transactionID;

- (id) initWithTransactionID :(NSString *)transactionID fromName:(NSString *)fromName toName:(NSString *)toName  amount:(NSNumber *)amount status:(NSString *) status date:(NSDate *)date
{
    if(self = [super init])
    {
        self.transactionID = transactionID;
        self.fromName = fromName;
        self.toName = toName;
        self.amount = amount;
        self.date = date;
        self.status = status;
    }
    
    return self;
}

@end
