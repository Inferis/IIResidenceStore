//
//  IISingleResidenceStore.m
//  ResidenceStoreDemo
//
//  Created by Tom Adriaenssen on 01/04/13.
//  Copyright (c) 2013 Tom Adriaenssen. All rights reserved.
//

#import "IISingleResidenceStore.h"

@implementation IISingleResidenceStore {
    IIResidenceStore* _store;
}

#pragma mark - initialization

- (id)initWithVerifier:(NSString*)verifier {
    if ((self = [IISingleResidenceStore new])) {
        _store = [IIResidenceStore storeWithVerifier:verifier];
        
        // find signed in email
        for (NSString* email in _store.allEmails) {
            _email = email;
            _residenceToken = [_store residenceTokenForEmail:email];
            if (_residenceToken && _residenceToken.length > 0)
                break;
        }
    }

    return self;
}

+ (IISingleResidenceStore*)singleStoreWithVerifier:(NSString*)verifier {
    return [[IISingleResidenceStore alloc] initWithVerifier:verifier];
}

#pragma mark - proxy properties

- (NSString *)verifier {
    return _store.verifier;
}

- (NSTimeInterval)verifierTimeout {
    return _store.verifierTimeout;
}

- (void)setVerifierTimeout:(NSTimeInterval)verifierTimeout {
    _store.verifierTimeout = verifierTimeout;
}

- (IIResidenceStore*)backingStore {
    return _store;
}


#pragma mark - state

- (BOOL)isVerifyingEmail {
    return (_email && _email.length > 0) && (!_residenceToken || _residenceToken.length == 0);
}

- (BOOL)isAuthenticated {
    return (_email && _email.length > 0) && (_residenceToken && _residenceToken.length > 0);
}

- (void)registerResidenceForEmail:(NSString*)email completion:(void(^)(BOOL success, NSError* error))completion {
    _email = nil;
    _residenceToken = nil;
    [_store registerResidenceForEmail:email completion:^(BOOL success, NSError *error) {
        _email = email;
        if (completion) completion(success, error);
    }];
}

- (void)registerResidenceForEmail:(NSString*)email userInfo:(NSString*)userInfo completion:(void(^)(BOOL success, NSError* error))completion {
    _email = nil;
    _residenceToken = nil;
    [_store registerResidenceForEmail:email userInfo:userInfo completion:^(BOOL success, NSError *error) {
        if (success) 
            _email = email;
        if (completion) completion(success, error);
    }];
}

- (void)verifyResidenceCompletion:(void(^)(BOOL success, NSError* error))completion {
    [_store verifyResidenceForEmail:_email completion:^(BOOL success, NSError *error) {
        if (success)
            _residenceToken = [_store residenceTokenForEmail:_email];
        
        if (completion) completion(success, error);
    }];
}

- (void)removeResidenceCompletion:(void(^)(BOOL success, NSError* error))completion {
    [_store removeResidenceForEmail:_email completion:^(BOOL success, NSError *error) {
        if (success) {
            _email = nil;
            _residenceToken = nil;
        }
        if (completion) completion(success, error);
    }];
}



@end
