//
//  SocializeAuthenticateService.m
//  SocializeSDK
//
//  Created by Fawad Haider on 6/13/11.
//  Copyright 2011 Socialize, Inc. All rights reserved.
//

#import "SocializeAuthenticateService.h"
#import "SocializeRequest.h"
#import "SocializeProvider.h"
#import "OAMutableURLRequest.h"
#import "OADataFetcher.h"
#import "OAAsynchronousDataFetcher.h"
#import <UIKit/UIKit.h>
#import "JSONKit.h"

@interface SocializeAuthenticateService()
-(NSString*)getSocializeId;
-(NSString*)getSocializeToken;
-(void)persistUserInfo:(NSDictionary*)dictionary;
-(void)persistConsumerInfo:(NSString*)apiKey andApiSecret:(NSString*)apiSecret;

@end

@implementation SocializeAuthenticateService

-(void)dealloc
{
    [fbAuth release]; fbAuth = nil;
    [super dealloc];
}

#define AUTHENTICATE_METHOD @"authenticate/"

-(void)authenticateWithApiKey:(NSString*)apiKey apiSecret:(NSString*)apiSecret{            
    NSString* payloadJson = [NSString stringWithFormat:@"{\"udid\":\"%@\"}", [UIDevice currentDevice].uniqueIdentifier];
    NSMutableDictionary* paramsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                payloadJson, @"jsonData",
                                                nil];

    [self persistConsumerInfo:apiKey andApiSecret:apiSecret];
    [self ExecuteSecurePostRequestAtEndPoint:AUTHENTICATE_METHOD WithParams:paramsDict expectedResponseFormat:SocializeDictionary];
}

+(BOOL)isAuthenticated {
    OAToken *authToken = [[[OAToken alloc ]initWithUserDefaultsUsingServiceProviderName:kPROVIDER_NAME prefix:kPROVIDER_PREFIX] autorelease];
    if (authToken.key)
        return YES;
    else
        return NO;
}

+ (BOOL)isAuthenticatedWithFacebook {
    return [self isAuthenticated] && [FacebookAuthenticator hasValidToken];
}

-(void)persistConsumerInfo:(NSString*)apiKey andApiSecret:(NSString*)apiSecret{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (userDefaults){
        [userDefaults setObject:apiKey forKey:kSOCIALIZE_API_KEY_KEY];
        [userDefaults setObject:apiSecret forKey:kSOCIALIZE_API_SECRET_KEY];
        [userDefaults synchronize];
    }
}

-(void)persistUserInfo:(NSDictionary*)dictionary{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (userDefaults){
        NSString* userId = [dictionary objectForKey:@"id"]; 
        if ((userId != nil) && ((id)userId != [NSNull null]))
            [userDefaults setObject:userId forKey:kSOCIALIZE_USERID_KEY];
        
        NSString* username = [dictionary objectForKey:@"username"]; 
        if ((username != nil) && ((id)username != [NSNull null]))
            [userDefaults setObject:username forKey:kSOCIALIZE_USERNAME_KEY];

        NSString* smallImageUri = [dictionary objectForKey:@"small_image_uri"]; 
        
        if ((smallImageUri != nil) && ((id)smallImageUri != [NSNull null]))
            [userDefaults setObject:smallImageUri forKey:kSOCIALIZE_USERIMAGEURI_KEY];
        
        [userDefaults synchronize];
    }
}

-(NSString*)getSocializeId{
    NSUserDefaults* userPreferences = [NSUserDefaults standardUserDefaults];
    NSString* userJSONObject = [userPreferences valueForKey:kSOCIALIZE_USERID_KEY];
    if (!userJSONObject)
        return @"";
    return userJSONObject;
}

-(NSString*)getSocializeToken{
    OAToken *authToken = [[[OAToken alloc ]initWithUserDefaultsUsingServiceProviderName:kPROVIDER_NAME prefix:kPROVIDER_PREFIX] autorelease];
    if (authToken.key)
        return authToken.key;
    else 
        return nil;
}

-(void)authenticateWithApiKey:(NSString*)apiKey
                            apiSecret:(NSString*)apiSecret 
                  thirdPartyAuthToken:(NSString*)thirdPartyAuthToken
                     thirdPartyAppId:(NSString*)thirdPartyAppId
                       thirdPartyName:(ThirdPartyAuthName)thirdPartyName
{
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
                             [UIDevice currentDevice].uniqueIdentifier,@"udid", 
                             [self getSocializeId],  @"socialize_id", 
                             @"1"/* auth type is for facebook*/ , @"auth_type", //TODO:: should be changed
                             thirdPartyAuthToken, @"auth_token",
                             thirdPartyAppId, @"auth_id" , nil] ;                        
                               
   [self persistConsumerInfo:apiKey andApiSecret:apiSecret];
   [self ExecuteSecurePostRequestAtEndPoint:AUTHENTICATE_METHOD WithParams:params expectedResponseFormat:SocializeDictionary];
}

-(void)authenticateWithApiKey:(NSString*)apiKey 
                    apiSecret:(NSString*)apiSecret 
              thirdPartyAppId:(NSString*)thirdPartyAppId 
         thirdPartyLocalAppId:(NSString*)thirdPartyLocalAppId 
               thirdPartyName:(ThirdPartyAuthName)thirdPartyName
{
    
    SocializeFacebook* fb = [[SocializeFacebook alloc] initWithAppId:thirdPartyAppId];

    [fbAuth release]; fbAuth = nil;
    fbAuth = [[FacebookAuthenticator alloc] initWithFramework:fb apiKey:apiKey apiSecret:apiSecret appId:thirdPartyAppId localAppId:thirdPartyLocalAppId service:self];
    [fb release]; fb = nil; 
    
    [fbAuth performAuthentication];
}

-(void)authenticateWithApiKey:(NSString*)apiKey 
                    apiSecret:(NSString*)apiSecret 
              thirdPartyAppId:(NSString*)thirdPartyAppId 
               thirdPartyName:(ThirdPartyAuthName)thirdPartyName
{
    [self authenticateWithApiKey:apiKey
                       apiSecret:apiSecret
                 thirdPartyAppId:thirdPartyAppId
            thirdPartyLocalAppId:nil
                  thirdPartyName:thirdPartyName];
}


/**
 * Called when an error prevents the request from completing successfully.
 */
- (void)request:(SocializeRequest *)request didFailWithError:(NSError *)error{
    [_delegate service:self didFail:error];
}

/**
 * Called when a request returns and its response has been parsed into
 * an object.
 *
 * The resulting object may be a dictionary, an array, a string, or a number,
 * depending on the format of the API response.
 */

- (void)request:(SocializeRequest *)request didLoadRawResponse:(NSData *)data{
    NSString *responseBody = [[NSString alloc] initWithData:data
                                                   encoding:NSUTF8StringEncoding];
    
    
    JSONDecoder *jsonKitDecoder = [JSONDecoder decoder];
    id jsonObject = [jsonKitDecoder objectWithData:data];
    
    if ([jsonObject isKindOfClass:[NSDictionary class]]){
        
        NSString* token_secret = [jsonObject objectForKey:@"oauth_token_secret"];
        NSString* token = [jsonObject objectForKey:@"oauth_token"];
        
        if (token_secret && token){
            OAToken *requestToken = [[OAToken alloc] initWithKey:token secret:token_secret];
            [requestToken storeInUserDefaultsWithServiceProviderName:kPROVIDER_NAME prefix:kPROVIDER_PREFIX];
            [requestToken release]; requestToken = nil;
            id<SocializeUser> user = [_objectCreator createObjectFromDictionary:[jsonObject objectForKey:@"user"] forProtocol:@protocol(SocializeUser)];
            if (([((NSObject*)_delegate) respondsToSelector:@selector(didAuthenticate:)]) )
                [_delegate didAuthenticate:user];
        }
        else if (([((NSObject*)_delegate) respondsToSelector:@selector(service:didFail:)]) ) 
            [_delegate service:self didFail:[NSError errorWithDomain:@"Socialize" code:400 userInfo:nil]];
            
        [self persistUserInfo:[jsonObject objectForKey:@"user"]];
    }
    
    [responseBody release];
    [self freeDelegate];
}

-(void)removeAuthenticationInfo
{

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString* key = [NSString stringWithFormat:@"OAUTH_%@_%@_KEY", kPROVIDER_PREFIX, kPROVIDER_NAME];
    NSString* secret = [NSString stringWithFormat:@"OAUTH_%@_%@_SECRET", kPROVIDER_PREFIX, kPROVIDER_NAME];
    
    if ([defaults objectForKey:key] && [defaults objectForKey:secret]) 
    {
        [defaults removeObjectForKey:key];
        [defaults removeObjectForKey:secret];
    }

    // Remove local facebook authentication info
    [defaults removeObjectForKey:@"FBAccessTokenKey"];
    [defaults removeObjectForKey:@"FBExpirationDateKey"];

    [defaults synchronize];    
}

+(BOOL)handleOpenURL:(NSURL *)url 
{    
    return [FacebookAuthenticator handleOpenURL:url]; 
}

-(BOOL)handleOpenURL:(NSURL *)url 
{    
    return [fbAuth handleOpenURL:url]; 
}

-(NSString*)receiveFacebookAuthToken
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"FBAccessTokenKey"];
}


@end


#pragma mark - Facebook authenticator

@interface FacebookAuthenticator()
    @property (nonatomic, retain) SocializeFacebook* facebook;
    @property (nonatomic, retain) NSString* apiKey;
    @property (nonatomic, retain) NSString* apiSecret;
    @property (nonatomic, retain) NSString* thirdPartyAppId;
    @property (nonatomic, retain) NSString* thirdPartyLocalAppId;
    @property (nonatomic, assign) SocializeAuthenticateService* service;

+ (void)setLastUsedAuthenticator:(FacebookAuthenticator*)newAuthenticator;

@end

static FacebookAuthenticator *FacebookAuthenticatorLastUsedAuthenticator;

@implementation FacebookAuthenticator
@synthesize facebook;
@synthesize apiKey;
@synthesize apiSecret;
@synthesize thirdPartyAppId;
@synthesize thirdPartyLocalAppId;
@synthesize service;

-(void)dealloc
{
    self.facebook = nil;
    [super dealloc];
}

-(id) initWithFramework: (SocializeFacebook*) fb 
                 apiKey: (NSString*) key 
              apiSecret: (NSString*) secret
                  appId: (NSString*)appId 
                service: (SocializeAuthenticateService*) authService
{
    return [self initWithFramework:fb apiKey:key apiSecret:secret appId:appId localAppId:nil service:authService];
}

-(id) initWithFramework: (SocializeFacebook*) fb 
                 apiKey: (NSString*) key 
              apiSecret: (NSString*) secret
                  appId: (NSString*)appId 
                  localAppId: (NSString*)localAppId 
                service: (SocializeAuthenticateService*) authService
{
    self = [super init];
    if(self)
    {
        self.facebook  = fb;
        self.apiKey = key;
        self.apiSecret = secret;
        self.thirdPartyAppId = appId;
        self.thirdPartyLocalAppId = localAppId;
        self.service = authService;
    }
    
    return self;
}

+ (BOOL)hasValidToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"FBAccessTokenKey"] != nil &&
        [[defaults objectForKey:@"FBExpirationDateKey"] timeIntervalSinceNow] > 0;
}

- (void)copyDefaultsToFacebookObject {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"FBAccessTokenKey"] 
        && [defaults objectForKey:@"FBExpirationDateKey"]) {
        self.facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
        self.facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
    }
}

-(void) performAuthentication
{
    [self copyDefaultsToFacebookObject];
    if (![self.facebook isSessionValid]) {

        // Store this authenticator for later retrieval from static class method handleOpenURL:
        [FacebookAuthenticator setLastUsedAuthenticator:self];
        [self.facebook authorize:nil delegate:self localAppId:self.thirdPartyLocalAppId];
    }
    else
    {
        [self.service authenticateWithApiKey:self.apiKey apiSecret:self.apiSecret thirdPartyAuthToken:self.facebook.accessToken thirdPartyAppId:self.thirdPartyAppId thirdPartyName:FacebookAuth];
    }

}

- (void)logout {
    [self copyDefaultsToFacebookObject];
    [self.facebook logout:self];
}

#pragma mark - Facebook delegate

/**
 * Called when the user successfully logged in.
 */
- (void)fbDidLogin
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[facebook accessToken] forKey:@"FBAccessTokenKey"];
    [defaults setObject:[facebook expirationDate] forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
    [service authenticateWithApiKey:self.apiKey apiSecret:self.apiSecret thirdPartyAuthToken:self.facebook.accessToken thirdPartyAppId:self.thirdPartyAppId thirdPartyName:FacebookAuth];
    
    [FacebookAuthenticator setLastUsedAuthenticator:nil];
}

/**
 * Called when the user dismissed the dialog without logging in.
 */
- (void)fbDidNotLogin:(BOOL)cancelled
{
    NSLog(@"User cancelled authentication");
    if(cancelled)
        [service request:nil didFailWithError:[NSError errorWithDomain:@"Socialize" code:400 userInfo:nil]];
    
    [FacebookAuthenticator setLastUsedAuthenticator:nil];
}

/**
 * Called when the user logged out.
 */
- (void)fbDidLogout
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"FBAccessTokenKey"];
    [defaults removeObjectForKey:@"FBExpirationDateKey"];
    [defaults synchronize];
}

+ (void)setLastUsedAuthenticator:(FacebookAuthenticator*)newAuthenticator {
    [newAuthenticator retain];
    [FacebookAuthenticatorLastUsedAuthenticator release];
    FacebookAuthenticatorLastUsedAuthenticator = newAuthenticator;
}

+ (BOOL)handleOpenURL:(NSURL*)url {
    return [FacebookAuthenticatorLastUsedAuthenticator handleOpenURL:url];
}

-(BOOL) handleOpenURL:(NSURL *)url
{
    return [self.facebook handleOpenURL: url];
}

@end