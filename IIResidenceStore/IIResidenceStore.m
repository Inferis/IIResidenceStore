//
//  IIResidenceStore.m
//  ResidenceStoreDemo
//
//  Created by Tom Adriaenssen on 21/03/13.
//  Copyright (c) 2013 Tom Adriaenssen. All rights reserved.
//

#import "IIResidenceStore.h"
#include <CommonCrypto/CommonDigest.h>

@interface IIResidenceStore ()

@end


@implementation IIResidenceStore {
    NSString* _key;
    NSOperationQueue* _queue;
}

#pragma mark - initialization

- (id)initWithVerifier:(NSString*)verifier {
    if (!verifier.length) return nil;
    
    if ((self = [self init])) {
        _verifier = verifier;
        _queue = [NSOperationQueue new];
        _verifierTimeout = 30;
        
        NSString* bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleIdentifierKey];
        
        NSString* escapedVerifier = [self encode:_verifier];
        escapedVerifier = [escapedVerifier stringByReplacingOccurrencesOfString:@"%" withString:@"."];
        _key = [NSString stringWithFormat:@"%@.%@", bundleId, _verifier];
    }
    return self;
}

+ (IIResidenceStore*)storeWithVerifier:(NSString*)verifier {
    return [[IIResidenceStore alloc] initWithVerifier:verifier];
}

#pragma mark - public interface

- (NSArray*)allEmails {
    NSArray* residences = [self residences];
    NSMutableArray* emails = [NSMutableArray arrayWithCapacity:residences.count];
    for (NSDictionary* residence in residences) {
        [emails addObject:residence[@"email"]];
    }
    return [NSArray arrayWithArray:emails];
}

- (BOOL)isEmailRegistered:(NSString*)email {
    NSDictionary* residence = [self residenceForEmail:email];
    return [residence[@"registered"] boolValue];
}

- (NSString*)residenceTokenForEmail:(NSString*)email {
    NSDictionary* residence = [self residenceForEmail:email];
    return residence[@"authorizationToken"];
}

- (void)registerResidenceForEmail:(NSString*)email completion:(void(^)(BOOL success, NSError* error))completion {
    [self registerResidenceForEmail:email userInfo:nil completion:completion];
}

- (void)registerResidenceForEmail:(NSString*)email userInfo:(NSString*)userInfo completion:(void(^)(BOOL success, NSError* error))completion {
    if (email.length == 0) {
        completion(NO, nil);
        return;
    }
    
    NSString* residenceId;
    @synchronized(_key) {
        NSDictionary* residence = [self residenceForEmail:email];
        if (!residence) {
            residenceId = [self generateTokenForEmail:email];
            residence = @{ @"email": email, @"residence": residenceId };
            [self updateResidence:residence];
        }
        else {
            residenceId = residence[@"residence"];
        }
    }
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionaryWithDictionary:@{
                                 @"email": email,
                                 @"residence": residenceId,
                                 }];
    if (userInfo && userInfo.length > 0)
        parameters[@"userInfo"] = userInfo;

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_verifier]];
    [request setTimeoutInterval:self.verifierTimeout];
    [request setHTTPMethod:@"POST"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPBody:[[self encodeParameters:parameters] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [NSURLConnection sendAsynchronousRequest:request queue:_queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (!completion) return;
        
        if (error) {
            completion(NO, error);
            return;
        }
        
        if (!data) {
            completion(NO, nil);
            return;
        }

        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        if ((httpResponse.statusCode / 100) != 2) {
            completion(NO, nil);
            return;
        }
        
        BOOL ok = NO;
        id item = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (item) {
            @synchronized(_key) {
                NSMutableDictionary* residence = [NSMutableDictionary dictionaryWithDictionary:[self residenceForEmail:email]];
                residence[@"verificationToken"] = item[@"verificationToken"];
                [residence removeObjectForKey:@"authorizationToken"]; // since it's no longer valid anyway
                ok = [self updateResidence:residence];
            }
        }
        
        completion(ok, nil);
    }];
}

- (void)verifyResidenceForEmail:(NSString*)email completion:(void(^)(BOOL success, NSError* error))completion {
    if (email.length == 0) {
        completion(NO, nil);
        return;
    }
    
    NSString* residenceId;
    NSString* token;
    @synchronized(_key) {
        NSDictionary* residence = [self residenceForEmail:email];
        if (residence) {
            residenceId = residence[@"residence"];
            token = residence[@"verificationToken"] ?: residence[@"authorizationToken"];
        }
    }

    if (!residenceId || !token) {
        completion(NO, nil);
        return;
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_verifier]];
    [request setHTTPMethod:@"GET"];
    [request addValue:@"application/json" forHTTPHeaderField:@"X-Residence"];
    [request addValue:token forHTTPHeaderField:@"Authorization"];
    [request setTimeoutInterval:self.verifierTimeout];
    
    [NSURLConnection sendAsynchronousRequest:request queue:_queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (!completion) return;
        
        if (error) {
            completion(NO, error);
            return;
        }
        
        if (!data) {
            completion(NO, nil);
            return;
        }
        
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        if ((httpResponse.statusCode / 100) != 2) {
            completion(NO, nil);
            return;
        }

        NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![email isEqualToString:json[@"email"]] || [json[@"authorizationToken"] length] == 0) {
            completion(NO, nil);
            return;
        }

        BOOL ok = NO;
        @synchronized(_key) {
            NSMutableDictionary* residence = [NSMutableDictionary dictionaryWithDictionary:[self residenceForEmail:email]];
            residence[@"authorizationToken"] = json[@"authorizationToken"];
            [residence removeObjectForKey:@"verificationToken"];
            ok = [self updateResidence:residence];
        }
        
        completion(ok, nil);
    }];
}


- (void)removeResidenceForEmail:(NSString*)email completion:(void(^)(BOOL success, NSError* error))completion {
    if (email.length == 0) {
        completion(NO, nil);
        return;
    }
    
    NSString* residenceId, *token;
    @synchronized(_key) {
        NSDictionary* residence = [self residenceForEmail:email];
        if (!residence) {
            completion(NO, nil);
            return;
        }
        else {
            residenceId = residence[@"residence"];
            token = residence[@"authorizationToken"];
        }
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[[NSURL URLWithString:_verifier] URLByAppendingPathComponent:token]];
    [request setHTTPMethod:@"DELETE"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request addValue:residenceId forHTTPHeaderField:@"X-Residence"];
    [request setTimeoutInterval:self.verifierTimeout];
    
    [NSURLConnection sendAsynchronousRequest:request queue:_queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (!completion) return;
        
        if (error) {
            completion(NO, error);
            return;
        }
        
        if (!data) {
            completion(NO, nil);
            return;
        }
        
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        if ((httpResponse.statusCode / 100) != 2) {
            completion(NO, nil);
            return;
        }
        
        @synchronized(_key) {
            [self deleteResidenceForEmail:email];
        }
        
        completion(YES, nil);
    }];
}

- (NSString*)encode:(NSString*)value {
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                 (CFStringRef)value,
                                                                 NULL,
                                                                 (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                 CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}

- (NSString*)encodeParameters:(NSDictionary*)parameters {
    NSMutableString* result = [NSMutableString string];
    
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (result.length) [result appendString:@"&"];
        [result appendFormat:@"%@=%@", [self encode:key], [self encode:[obj description]]];
    }];

    return result;
}

- (NSString*)uniqueIdentifierForEmail:(NSString*)email {
    return [[[[UIDevice currentDevice] identifierForVendor] UUIDString] stringByAppendingString:email];
}

- (NSString*)generateTokenForEmail:(NSString*)email {
    if (email.length == 0)
        return nil;
    
    NSString* digest = [self uniqueIdentifierForEmail:email];
    
    uint8_t sha1hash[CC_SHA1_DIGEST_LENGTH];
    NSData* encoded = [digest dataUsingEncoding:NSUTF8StringEncoding];
    
    if (!CC_SHA1(encoded.bytes, encoded.length, sha1hash)) {
        return nil;
    }
    
    NSMutableString* hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for(int i=0; i<CC_SHA1_DIGEST_LENGTH; i++){
        [hex appendFormat:@"%02X", sha1hash[i]];
    }
    return hex;
}


#pragma mark - bookkeeping

- (NSMutableArray*)residences {
    
    NSDictionary* query = @{
                            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
                            (__bridge id)kSecAttrService: _key
                            };
    
    CFDataRef data = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&data);
    if (status != errSecSuccess) {
        if (status != errSecItemNotFound)
            NSLog(@"failed to get residences (key=%@), error: %ld", _key, status);
        return nil;
    }
    
    if (!data)
        return nil;
    
    return [NSJSONSerialization JSONObjectWithData:(__bridge_transfer NSData*)data
                                           options:NSJSONReadingMutableContainers
                                             error:nil];
}

- (BOOL)setResidences:(NSArray*)residences {
    NSError* error = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:residences options:0 error:&error];
    if (!data || error) {
        NSLog(@"could not store residences: serialization failed with error %@", error);
    }
    
    NSDictionary* query = @{
                            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                            (__bridge id)kSecValueData: data,
                            (__bridge id)kSecAttrService: _key
                            };
    
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    if (status == errSecDuplicateItem) {
        NSDictionary* delete = @{
                                 (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                 (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
                                 (__bridge id)kSecAttrService: _key
                                 };
        OSStatus deleteStatus = SecItemDelete((__bridge CFDictionaryRef)delete);
        if (deleteStatus == errSecSuccess)
            status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
        else
            NSLog(@"could not store residences: tried to delete item but failed for key %@: %ld", _key, deleteStatus);
    }
    
    if (status != errSecSuccess)
        NSLog(@"could not store residences: SecItemAdd failed for key %@: %ld", _key, status);
    
    return (status == errSecSuccess);
}

- (BOOL)removeAllResidences {
    NSDictionary* delete = @{
                             (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                             (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
                             (__bridge id)kSecAttrService: _key
                             };
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)delete);
    if (status != errSecSuccess && status != errSecItemNotFound)
        NSLog(@"could not store residences: tried to delete item but failed for key %@: %ld", _key, status);

    return (status == errSecSuccess);
}

- (NSDictionary*)residenceForEmail:(NSString*)email {
    if (email.length == 0)
        return nil;
    
    NSArray* residences = [self residences];
    for (NSDictionary* residence in residences) {
        if ([email isEqualToString:[residence[@"email"] lowercaseString]])
            return residence;
    }
    
    return nil;
}

- (BOOL)deleteResidenceForEmail:(NSString*)email {
    if (email.length == 0)
        return NO;
    
    NSMutableArray* residences = [self residences] ?: [NSMutableArray arrayWithCapacity:1];
    NSDictionary* remove = nil;
    email = [email lowercaseString];
    for (NSDictionary* existing in residences) {
        if ([email isEqualToString:[existing[@"email"] lowercaseString]]) {
            remove = existing;
            break;
        }
    }
    
    if (remove) {
        [residences removeObject:remove];
        return [self setResidences:residences];
    }
    
    return NO;
}

- (BOOL)updateResidence:(NSDictionary*)residence {
    if (!residence)
        return NO;
    
    NSMutableArray* residences = [self residences] ?: [NSMutableArray arrayWithCapacity:1];
    NSDictionary* remove = nil;
    NSString* email = [residence[@"email"] lowercaseString];
    for (NSDictionary* existing in residences) {
        if ([email isEqualToString:[existing[@"email"] lowercaseString]]) {
            remove = existing;
            break;
        }
    }
    
    [residences removeObject:remove];
    [residences addObject:residence];
    
    return [self setResidences:residences];
}



@end
