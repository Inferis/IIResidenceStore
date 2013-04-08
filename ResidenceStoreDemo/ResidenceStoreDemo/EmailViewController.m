//
//  EmailViewController.m
//  ResidenceStoreDemo
//
//  Created by Tom Adriaenssen on 06/04/13.
//  Copyright (c) 2013 Tom Adriaenssen. All rights reserved.
//

#import "EmailViewController.h"

@interface EmailViewController () <UITextFieldDelegate>

@property (nonatomic, weak) IBOutlet UITextField* emailField;

@end

@implementation EmailViewController {
    IIResidenceStore* _store;
    void(^_callback)(NSString* email);
}

- (id)initWithStore:(IIResidenceStore*)store callback:(void(^)(NSString* email))callback;
{
    self = [self initWithNibName:nil bundle:nil];
    if (self) {
        _store = store;
        _callback = callback;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self.emailField becomeFirstResponder];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    string = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    self.navigationItem.rightBarButtonItem.enabled = string.length > 0;
    return YES;
}

- (void)done
{
    _callback(self.emailField.text);
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
