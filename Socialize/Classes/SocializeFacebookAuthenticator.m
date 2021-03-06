//
//  SocializeFacebookAuthenticator.m
//  SocializeSDK
//
//  Created by Nathaniel Griswold on 2/26/12.
//  Copyright (c) 2012 Socialize, Inc. All rights reserved.
//

#import "SocializeFacebookAuthenticator.h"
#import "_Socialize.h"
#import "SocializeErrorDefinitions.h"
#import "SocializeUIDisplayProxy.h"
#import "SocializeThirdPartyFacebook.h"
#import "SocializeFacebookAuthHandler.h"


@implementation SocializeFacebookAuthenticator
@synthesize options = options_;
@synthesize facebookAuthHandler = facebookAuthHandler_;
@synthesize thirdParty = thirdParty_;

- (void)dealloc {
    self.options = nil;
    self.facebookAuthHandler = nil;
    
    [super dealloc];
}

+ (void)authenticateViaFacebookWithOptions:(SocializeFacebookAuthOptions*)options
                                   display:(id)display
                                   success:(void(^)())success
                                   failure:(void(^)(NSError *error))failure {
    
    SocializeFacebookAuthenticator *auth = [[[self alloc] initWithOptions:options display:display] autorelease];
    auth.successBlock = success;
    auth.failureBlock = failure;

    [SocializeAction executeAction:auth];
}

+ (void)authenticateViaFacebookWithOptions:(id)options
                              displayProxy:(SocializeUIDisplayProxy*)proxy
                                   success:(void(^)())success
                                   failure:(void(^)(NSError *error))failure {
    SocializeFacebookAuthenticator *auth = [[[self alloc] initWithOptions:options displayProxy:proxy] autorelease];
    auth.successBlock = success;
    auth.failureBlock = failure;
    
    [SocializeAction executeAction:auth];
}

- (BOOL)permissionDialogNotPossible {
    // UIAlertView transition breaks an immediately following facebook internal modal controller display
    // Internal modal is shown only for devices that will fail to open safari urls, which currently
    // is only known to be low-memory devices on iOS 4.
    // Unfortunately, canOpenURL: will return YES, but openURL: will in fact fail for this particular case
    // However, devices that suffer from this problem can not make it past 4.3
    double systemVersion = [[[UIDevice currentDevice] systemVersion] doubleValue];
    return systemVersion < 4.3;
}

- (Class)thirdParty {
    if (thirdParty_ == nil) {
        thirdParty_ = [SocializeThirdPartyFacebook class];
    }
    
    return thirdParty_;
}

- (void)willSucceed {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:NO] forKey:kSOCIALIZE_DONT_POST_TO_FACEBOOK_KEY];
    [defaults synchronize];
}

- (SocializeFacebookAuthHandler*)facebookAuthHandler {
    if (facebookAuthHandler_ == nil) {
        facebookAuthHandler_ = [[SocializeFacebookAuthHandler sharedFacebookAuthHandler] retain];
    }
    
    return facebookAuthHandler_;
}

- (void)attemptInteractiveLogin {
    NSString *facebookAppId = [SocializeThirdPartyFacebook facebookAppId];
    NSString *urlSchemeSuffix = [SocializeThirdPartyFacebook facebookUrlSchemeSuffix];
    
    NSArray *permissions = self.options.permissions;
    if (permissions == nil) {
        permissions = [NSArray arrayWithObjects:@"publish_stream", @"offline_access", nil];
    }
    __block __typeof__(self) weakSelf = self;
    [self.facebookAuthHandler authenticateWithAppId:facebookAppId
                                    urlSchemeSuffix:urlSchemeSuffix
                                        permissions:permissions
                                            success:^(NSString *accessToken, NSDate *expirationDate) {
                                                [SocializeThirdPartyFacebook storeLocalCredentialsWithAccessToken:accessToken
                                                                                                   expirationDate:expirationDate];
                                                
                                                [weakSelf succeedInteractiveLogin];
                                            } failure:^(NSError *error) {
                                                [weakSelf failWithError:error];
                                            }];
}

- (NSError*)userAbortedAuthError {
    return [NSError defaultSocializeErrorForCode:SocializeErrorFacebookCancelledByUser];
}

@end
