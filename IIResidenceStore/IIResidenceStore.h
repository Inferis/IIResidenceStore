//
//  IIResidenceStore.h
//  ResidenceStoreDemo
//
//  Created by Tom Adriaenssen on 21/03/13.
//  Copyright (c) 2013 Tom Adriaenssen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IIResidenceStore : NSObject

@property (nonatomic, strong, readonly) NSString* verifier;
@property (nonatomic, assign) NSTimeInterval verifierTimeout;

- (NSArray*)allEmails;
- (BOOL)isEmailRegistered:(NSString*)email;
- (NSString*)residenceTokenForEmail:(NSString*)email;

- (BOOL)removeAllResidences;

- (void)registerResidenceForEmail:(NSString*)email completion:(void(^)(BOOL success, NSError* error))completion;
- (void)registerResidenceForEmail:(NSString*)email userInfo:(NSString*)userInfo completion:(void(^)(BOOL success, NSError* error))completion;
- (void)verifyResidenceForEmail:(NSString*)email completion:(void(^)(BOOL success, NSError* error))completion;
- (void)removeResidenceForEmail:(NSString*)email completion:(void(^)(BOOL success, NSError* error))completion;

- (NSString*)uniqueIdentifierForEmail:(NSString*)email;

+ (IIResidenceStore*)storeWithVerifier:(NSString*)verifier;

@end

