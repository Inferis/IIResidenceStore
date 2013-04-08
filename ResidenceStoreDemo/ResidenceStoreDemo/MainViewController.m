//
//  MainViewController.m
//  ResidenceStoreDemo
//
//  Created by Tom Adriaenssen on 04/04/13.
//  Copyright (c) 2013 Tom Adriaenssen. All rights reserved.
//

#import "MainViewController.h"
#import "EmailViewController.h"
#import "IISingleResidenceStore.h"
#import "Tin.h"
#import "Tin+BasicAuthentication.h"
#import "TinResponse.h"
#import "SVProgressHUD.h"

@interface MainViewController () <UIAlertViewDelegate>

@property (nonatomic, weak) IBOutlet UILabel* statusLabel;
@property (nonatomic, weak) IBOutlet UILabel* residencesLabel;
@property (nonatomic, weak) IBOutlet UILabel* registrationsLabel;
@property (nonatomic, weak) IBOutlet UILabel* verificationsLabel;
@property (nonatomic, weak) IBOutlet UILabel* removalsLabel;
@property (nonatomic, weak) IBOutlet UILabel* tapsLabel;
@property (nonatomic, weak) IBOutlet UIButton* tapsButton;

@end

@implementation MainViewController {
    IISingleResidenceStore* _store;
}

static NSString* baseUri = @"http://residencedemo.blergh.be";

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _store = [IISingleResidenceStore singleStoreWithVerifier:[baseUri stringByAppendingPathComponent:@"residence"]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_statusLabel];
    
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
    [_store verifyResidenceCompletion:^(BOOL success, NSError *error) {
        [SVProgressHUD dismiss];
        if (!success) {
            // not verified
            [self notLoggedIn];
        }
        else {
            [self loggedIn];
        }
    }];
}

- (void)logout {
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
    [_store removeResidenceCompletion:^(BOOL success, NSError *error) {
        [SVProgressHUD dismiss];
        UIAlertView* alert;
        if (success) {
            [self notLoggedIn];
            alert = [[UIAlertView alloc] initWithTitle:@"Unregistered" message:@"This device was unregistered at the service." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        }
        else {
            [self loggedIn];
            alert = [[UIAlertView alloc] initWithTitle:@"Failed!" message:@"Could not unregister this device at the service." delegate:nil cancelButtonTitle:@"Damn" otherButtonTitles:nil];
        }
        
        [alert show];
    }];
}

- (void)login {
    EmailViewController* controller = [[EmailViewController alloc] initWithStore:_store.backingStore callback:^(NSString *email) {
        if (email) {
            [self registerEmail:email];
        }
    }];
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:controller] animated:NO completion:nil];
}

- (void)registerEmail:(NSString*)email {
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
    [_store registerResidenceForEmail:email completion:^(BOOL success, NSError *error) {
        [SVProgressHUD dismiss];
        if (!success) {
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Failed!" message:@"Could not register this device at the service." delegate:nil cancelButtonTitle:@"Damn" otherButtonTitles:nil];
            [alert show];
        }
        else {
            [self verifyEmail];
        }
    }];
}

- (void)verifyEmail {
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
    [_store verifyResidenceCompletion:^(BOOL success, NSError *error) {
        [SVProgressHUD dismiss];
        if (!success) {
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Not confirmed" message:@"It seems you didn't click the link in the email yet. If you didn't receive it, we can send it again. What do you think?" delegate:self cancelButtonTitle:@"Yes, send it" otherButtonTitles:@"I'll check again", nil];
            [alert show];
        }
        else {
            [self loggedIn];
        }
    }];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [self registerEmail:_store.email];
    }
    else {
        [self verifyEmail];
    }
}

- (IBAction)tapped:(id)sender {
    [SVProgressHUD showWithStatus:@"Tapping" maskType:SVProgressHUDMaskTypeGradient];
    Tin* tin = [[Tin new] authenticateWithToken:_store.residenceToken];
    tin.accept = @"application/json";
    tin.bodyParameterEncoding = TinFormURLParameterEncoding;
    NSDictionary* query = @{ @"tapTime": @((int)[[NSDate date] timeIntervalSince1970]) };
    [tin post:[baseUri stringByAppendingPathComponent:@"demo"] body:query success:^(TinResponse *response) {
        [SVProgressHUD dismiss];
        [self handleResponse:response.parsedResponse];
    }];
}

- (void)notLoggedIn {
    _statusLabel.text = @"Not logged in";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Login" style:UIBarButtonItemStylePlain target:self action:@selector(login)];
    
    UIColor* color = [UIColor colorWithWhite:0 alpha:0.5];
    self.residencesLabel.textColor = color;
    self.residencesLabel.text = @"?";
    self.registrationsLabel.textColor = color;
    self.registrationsLabel.text = @"?";
    self.verificationsLabel.textColor = color;
    self.verificationsLabel.text = @"?";
    self.removalsLabel.textColor = color;
    self.removalsLabel.text = @"?";
    self.tapsLabel.textColor = color;
    self.tapsLabel.text = @"?";
    self.tapsButton.enabled = NO;
}

- (void)loggedIn {
    _statusLabel.text = _store.email;
    UIColor* color = [UIColor blackColor];
    self.residencesLabel.textColor = color;
    self.registrationsLabel.textColor = color;
    self.verificationsLabel.textColor = color;
    self.removalsLabel.textColor = color;
    self.tapsLabel.textColor = color;
    self.tapsButton.enabled = YES;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStylePlain target:self action:@selector(logout)];

    [SVProgressHUD showWithStatus:@"Getting info" maskType:SVProgressHUDMaskTypeGradient];
    Tin* tin = [[Tin new] authenticateWithToken:_store.residenceToken];
    tin.accept = @"application/json";
    [tin get:[baseUri stringByAppendingPathComponent:@"demo"] success:^(TinResponse *response) {
        [SVProgressHUD dismiss];
        [self handleResponse:response.parsedResponse];
    }];
}

- (void)handleResponse:(id)response {
    UIColor* color = [UIColor blackColor];
    if (response) {
        self.residencesLabel.text = [NSString stringWithFormat:@"%@", response[@"Residences"]];
        self.registrationsLabel.text = [NSString stringWithFormat:@"%@", response[@"Registrations"]];
        self.verificationsLabel.text = [NSString stringWithFormat:@"%@", response[@"Verifications"]];
        self.removalsLabel.text = [NSString stringWithFormat:@"%@", response[@"Removals"]];
        self.tapsLabel.text = [NSString stringWithFormat:@"%@", response[@"Taps"]];
    }
    else {
        color = [UIColor redColor];
    }
    self.residencesLabel.textColor = color;
    self.registrationsLabel.textColor = color;
    self.verificationsLabel.textColor = color;
    self.removalsLabel.textColor = color;
    self.tapsLabel.textColor = color;
}

@end
