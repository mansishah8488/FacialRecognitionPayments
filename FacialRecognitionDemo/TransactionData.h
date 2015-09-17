//
//  TransactionData.h
//  FacialRecognitionDemo
//
//  Created by Shah, Mansi on 7/21/15.
//  Copyright (c) 2015 Shah, Mansi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TransactionData : NSObject
{
    NSString *_transactionID;
    NSString *_fromName;
    NSString *_toName;
    NSString *_status;
    NSNumber *_amount;
    NSDate *_date;
}


@property (nonatomic, strong) NSString *transactionID;
@property (nonatomic, strong) NSString *fromName;
@property (nonatomic, strong) NSString *toName;
@property (nonatomic, strong) NSNumber *amount;
@property (nonatomic,strong) NSString *status;
@property (nonatomic,strong) NSDate * date;



- (id) initWithTransactionID :(NSString *)transactionID fromName:(NSString *)fromName toName:(NSString *)toName  amount:(NSNumber *)amount status:(NSString *) status date:(NSDate *)date;


@end
