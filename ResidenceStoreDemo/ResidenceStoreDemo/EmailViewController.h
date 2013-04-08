//
//  EmailViewController.h
//  ResidenceStoreDemo
//
//  Created by Tom Adriaenssen on 06/04/13.
//  Copyright (c) 2013 Tom Adriaenssen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IIResidenceStore.h"

@interface EmailViewController : UIViewController

- (id)initWithStore:(IIResidenceStore*)store callback:(void(^)(NSString* email))callback;

@end
