//
//  IISingleResidenceStore.h
//  ResidenceStoreDemo
//
//  Created by Tom Adriaenssen on 01/04/13.
//  Copyright (c) 2013 Tom Adriaenssen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IIResidenceStore.h"

@interface IISingleResidenceStore : NSObject

@property (nonatomic, strong, readonly) NSString* email;
@property (nonatomic, strong, readonly) NSString* residenceToken;
@property (nonatomic, strong, readonly) NSString* verifier;
@property (nonatomic, assign) NSTimeInterval verifierTimeout;
@property (nonatomic, strong, readonly) IIResidenceStore* backingStore;


- (BOOL)isVerifyingEmail;
- (BOOL)isAuthenticated;

- (void)registerResidenceForEmail:(NSString*)email completion:(void(^)(BOOL success, NSError* error))completion;
- (void)registerResidenceForEmail:(NSString*)email userInfo:(NSString*)userInfo completion:(void(^)(BOOL success, NSError* error))completion;
- (void)verifyResidenceCompletion:(void(^)(BOOL success, NSError* error))completion;
- (void)removeResidenceCompletion:(void(^)(BOOL success, NSError* error))completion;

+ (IISingleResidenceStore*)singleStoreWithVerifier:(NSString*)verifier;

@end
