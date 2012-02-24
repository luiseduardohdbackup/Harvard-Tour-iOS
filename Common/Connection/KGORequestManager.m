#import "KGORequestManager.h"
#import "Foundation+KGOAdditions.h"
#import "KGOAppDelegate+ModuleAdditions.h"
#import "CoreDataManager.h"
#import "Reachability.h"
#import "KGOModule.h"

#ifdef DEBUG
#import "KGOUserSettingsManager.h"
#endif

NSString * const CurrentKurogoServerSettingKey = @"CURRENT_KUROGO_SERVER";

@implementation KGORequestManager

@synthesize host = _host, loginPath;

+ (KGORequestManager *)sharedManager {
	static KGORequestManager *s_sharedManager = nil;
	if (s_sharedManager == nil) {
		s_sharedManager = [[KGORequestManager alloc] init];
	}
	return s_sharedManager;
}

- (BOOL)isReachable
{
    return [_reachability currentReachabilityStatus] != NotReachable;
}

- (BOOL)isModuleAvailable:(ModuleTag *)moduleTag
{
    // TODO: add this to hello API
    return YES;
}

- (BOOL)isModuleAuthorized:(ModuleTag *)moduleTag
{
    KGOModule *module = [KGO_SHARED_APP_DELEGATE() moduleForTag:moduleTag];
    return module.hasAccess;
}

- (NSURL *)serverURL {
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", _uriScheme, _extendedHost]];
}

- (NSURL *)hostURL {
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", _uriScheme, _host]];
}

#pragma mark -

- (KGORequest *)requestWithDelegate:(id<KGORequestDelegate>)delegate
                             module:(ModuleTag *)module // TODO: now that we have hello, we should check parameter validity
                               path:(NSString *)path
                            version:(NSUInteger)version
                             params:(NSDictionary *)params
{
	BOOL authorized = YES; // TODO: determine this value

    // TODO: add version parameters v and vmin.  this will become required.

	KGORequest *request = nil;
	if (authorized) {
		request = [[[KGORequest alloc] init] autorelease];
		request.delegate = delegate;
        request.apiMaxVersion = version;
        request.apiMinVersion = version;
        NSURL *requestBaseURL;
        if (module) {
            requestBaseURL = [[_baseURL URLByAppendingPathComponent:module] URLByAppendingPathComponent:path];
        } else {
            requestBaseURL = [_baseURL URLByAppendingPathComponent:path];
        }

		NSMutableDictionary *mutableParams = [[params mutableCopy] autorelease];
        if (mutableParams == nil) {
            // make sure this is not nil in case we want to auto-append parameters
            mutableParams = [NSMutableDictionary dictionary];
        }
        
        [mutableParams setObject:[NSString stringWithFormat:@"%d", version] forKey:@"v"];

		if (_accessToken) {
			[mutableParams setObject:_accessToken forKey:@"token"];
		}

#ifdef DEBUG
        [mutableParams setObject:@"1" forKey:@"debug"];
#endif

		request.url = [NSURL URLWithQueryParameters:mutableParams baseURL:requestBaseURL];
		request.module = module;
		request.path = path;
		request.getParams = mutableParams;
	} else {
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:nil];
		NSError *error = [NSError errorWithDomain:KGORequestErrorDomain code:KGORequestErrorForbidden userInfo:userInfo];
		[self showAlertForError:error request:request];
	}
	return request;
}

#pragma mark Errors

- (void)showAlertForError:(NSError *)error request:(KGORequest *)request
{
    [self showAlertForError:error request:request delegate:self];
}

- (void)showAlertForError:(NSError *)error request:(KGORequest *)request delegate:(id<UIAlertViewDelegate>)delegate
{
    DLog(@"%d %@", [error code], [error userInfo]);
    
	NSString *title = nil;
	NSString *message = nil;
    BOOL canRetry = NO;
	
	switch ([error code]) {
		case KGORequestErrorBadRequest: case KGORequestErrorUnreachable:
			title = NSLocalizedString(@"CORE_CONNECTION_FAILED_TITLE", @"Connection Failed");
			message = NSLocalizedString(@"CORE_CONNECTION_FAILED_MESSAGE", @"Could not connect to server. Please try again later.");
            canRetry = YES;
			break;
		case KGORequestErrorDeviceOffline:
			title = NSLocalizedString(@"CORE_DEVICE_OFFLINE_TITLE", @"Connection Failed");
			message = NSLocalizedString(@"CORE_DEVICE_OFFLINE_MESSAGE", @"Please check your Internet connection and try again.");
            canRetry = YES;
			break;
		case KGORequestErrorTimeout:
			title = NSLocalizedString(@"CORE_CONNECTION_TIMED_OUT_TITLE", @"Connection Timed Out");
			message = NSLocalizedString(@"CORE_CONNECTION_TIMED_OUT_MESSAGE", @"Server is taking too long to respond. Please try again later.");
            canRetry = YES;
			break;
		case KGORequestErrorForbidden:
			title = NSLocalizedString(@"CORE_UNAUTHORIZED_REQUEST_TITLE", @"Unauthorized Request");
			message = NSLocalizedString(@"CORE_UNAUTHORIZED_REQUEST_MESSAGE", @"Unable to perform this request. Please check your login credentials.");
			break;
		case KGORequestErrorVersionMismatch:
			title = NSLocalizedString(@"CORE_UNSUPPORTED_REQUEST_TITLE", @"Unsupported Request");
			NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
			message = [NSString stringWithFormat:
                       NSLocalizedString(@"CORE_UNSUPPORTED_REQUEST_MESSAGE", @"Request is not supported in this version of %@"),
					   [infoDict objectForKey:@"CFBundleName"]];
			break;
		case KGORequestErrorBadResponse: case KGORequestErrorOther: case KGORequestErrorResponseTypeMismatch:
			title = NSLocalizedString(@"CORE_CONNECTION_FAILED_TITLE", @"Connection Failed");
			message = NSLocalizedString(@"CORE_CONNECTION_FAILED_MESSAGE", @"Could not connect to server. Please try again later.");
            canRetry = YES;
			break;
		case KGORequestErrorServerMessage:
			title = [[error userInfo] nonemptyStringForKey:@"title"];
			message = [[error userInfo] nonemptyStringForKey:@"message"];
			break;
		case KGORequestErrorInterrupted: // don't show alert
		default:
			break;
	}
	
	if (title) {
        if (delegate == self) {
            [_retryRequest release];
            _retryRequest = [request retain];
        }
        
        NSString *retryOption = nil;
        if (canRetry) {
            retryOption = NSLocalizedString(@"CORE_RETRY_REQUEST_BUTTON", @"Retry");
        }
        
        
		UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:title
                                                             message:message
                                                            delegate:delegate
                                                   cancelButtonTitle:NSLocalizedString(@"COMMON_CANCEL", @"Cancel")
                                                   otherButtonTitles:retryOption, nil] autorelease];
		[alertView show];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != [alertView cancelButtonIndex]) {
        [_retryRequest connect];
        [_retryRequest release];
        _retryRequest = nil;
    }
}

#pragma mark Push notifications

NSString * const KGOPushDeviceIDKey = @"KGOPushDeviceID";
NSString * const KGOPushDevicePassKeyKey = @"KGOPushDevicePassKey";
NSString * const KGODeviceTokenKey = @"KGODeviceToken";

- (void)registerNewDeviceToken
{
    
    if (!self.devicePushToken) {
        DLog(@"cannot register nil device token");
        return;
    }
    
    if (_deviceRegistrationRequest) {
        DLog(@"device registration request already in progress");
        return;
    }
    
    NSDictionary *params = nil;

    // this will be of the form "<21d34 2323a 12324>"
    NSString *hex = [self.devicePushToken description];
	// eliminate the "<" and ">" and " "
	hex = [hex stringByReplacingOccurrencesOfString:@"<" withString:@""];
	hex = [hex stringByReplacingOccurrencesOfString:@">" withString:@""];
	hex = [hex stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    if (self.devicePushID && self.devicePushPassKey) {
        // we should only get here if Apple changes our device token,
        // which we've never actually seen happen before
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  self.devicePushID, @"device_id",
                  self.devicePushPassKey, @"pass_key",
                  @"ios", @"platform",
                  hex, @"device_token",
                  nil];
        
        // TODO: do something safer than hard coding "push" as the module tag
        _deviceRegistrationRequest = [self requestWithDelegate:self
                                                        module:@"push"
                                                          path:@"updatetoken"
                                                       version:1
                                                        params:params];
        
    } else {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"ios", @"platform",
                  hex, @"device_token",
                  nil];
        
        // TODO: do something safer than hard coding "push" as the module tag
        _deviceRegistrationRequest = [self requestWithDelegate:self
                                                        module:@"push"
                                                          path:@"register"
                                                       version:1
                                                        params:params];
    }
    
    [_deviceRegistrationRequest connect];
}

- (NSString *)devicePushID
{
    // if the user doesn't register,
    // this will keep doing extra work and returning nil anyway
    if (!_devicePushID) {
        _devicePushID = [[[NSUserDefaults standardUserDefaults] stringForKey:KGOPushDeviceIDKey] retain];
    }
    return _devicePushID;
}

- (NSString *)devicePushPassKey
{
    if (!_devicePushPassKey) {
        _devicePushPassKey = [[[NSUserDefaults standardUserDefaults] stringForKey:KGOPushDevicePassKeyKey] retain];
    }
    return _devicePushPassKey;
}

- (NSData *)devicePushToken
{
    return [[NSUserDefaults standardUserDefaults] dataForKey:KGODeviceTokenKey];
}

- (void)setDevicePushToken:(NSData *)devicePushToken
{
    [[NSUserDefaults standardUserDefaults] setObject:devicePushToken forKey:KGODeviceTokenKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark initialization

NSString * const kHTTPURIScheme = @"http";
NSString * const kHTTPSURIScheme = @"https";

- (void)selectServerConfig:(NSString *)config
{
    NSDictionary *configDict = [KGO_SHARED_APP_DELEGATE() appConfig];
    NSDictionary *servers = [configDict objectForKey:KGOAppConfigKeyServers];
    
    NSDictionary *serverConfig = [servers dictionaryForKey:config];
    if (serverConfig) {
        BOOL useHTTPS = [serverConfig boolForKey:@"UseHTTPS"];
        NSString *apiPath = [serverConfig objectForKey:@"APIPath"];
        NSString *pathExtension = [serverConfig nonemptyStringForKey:@"PathExtension"];

        @synchronized(self) {
            _uriScheme = useHTTPS ? kHTTPSURIScheme : kHTTPURIScheme;
            
            [_host release];
            
            _host = [[serverConfig objectForKey:@"Host"] retain];
            
            [_extendedHost release];
            if (pathExtension) {
                _extendedHost = [[NSString alloc] initWithFormat:@"%@/%@", _host, pathExtension];
            } else {
                _extendedHost = [_host copy];
            }
            
            [_baseURL release];
            _baseURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@://%@/%@", _uriScheme, _extendedHost, apiPath]];
            
            [_reachability release];

            _reachability = [[Reachability reachabilityWithHostName:[NSString stringByTrimmingURLPortNumber:_host]] retain];
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *oldServer = [defaults stringForKey:CurrentKurogoServerSettingKey];
        NSString *newServer = [_baseURL absoluteString];
        if (!oldServer) {
            [defaults setObject:newServer forKey:CurrentKurogoServerSettingKey];
        } else if (![oldServer isEqualToString:newServer]) {
            // TODO: handle this in a more customizable way.
            AlertLog(@"deleting core data store due to server change");
            
            [[CoreDataManager sharedManager] deleteStore];
            [defaults setObject:newServer forKey:CurrentKurogoServerSettingKey];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:KGOServerDidChangeNotification
                                                                object:self];
        }
        
    }
}

#ifdef DEBUG
- (void)selectServerConfigFromPreferences
{
    NSString *serverSetting = [[KGOUserSettingsManager sharedManager] selectedValueForSetting:KGOUserSettingKeyServer];
    if (serverSetting) {
        [self selectServerConfig:serverSetting];
    } else {
        [self selectServerConfig:@"Production"];
    }
}
#endif

- (id)init {
    self = [super init];
    if (self) {
#ifdef DEBUG
        [self selectServerConfigFromPreferences];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(selectServerConfigFromPreferences)
                                                     name:KGOUserPreferencesDidChangeNotification
                                                   object:nil];
#else
    #ifdef STAGING
        [self selectServerConfig:@"Staging"];
    #else
        [self selectServerConfig:@"Production"];
    #endif
#endif

        self.devicePushToken = [[NSUserDefaults standardUserDefaults] objectForKey:KGODeviceTokenKey];
	}
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	self.host = nil;
    
    [_helloRequest cancel];
    [_sessionRequest cancel];
    [_logoutRequest cancel];
    [_deviceRegistrationRequest cancel];
    
    [_extendedHost release];
    [_reachability release];
	[_uriScheme release];
	[_accessToken release];
    
    [_devicePushID release];
    [_devicePushPassKey release];
    self.devicePushToken = nil;
	[super dealloc];
}

#pragma mark auth

- (void)requestServerHello
{
    _helloRequest = [self requestWithDelegate:self
                                       module:nil
                                         path:@"hello"
                                      version:1
                                       params:nil];
    _helloRequest.expectedResponseType = [NSDictionary class];
    [_helloRequest connect];
}


- (void)loginKurogoServer
{
    if ([self isUserLoggedIn]) {
        DLog(@"user is already logged in");
        [[NSNotificationCenter defaultCenter] postNotificationName:KGODidLoginNotification object:self];
        
    } else {
        DLog(@"attempting to show modal login screen");
        UIViewController *homescreen = [KGO_SHARED_APP_DELEGATE() homescreen];
        if (homescreen.modalViewController) {
            DLog(@"already showing modal login screen");
            return;
        }
        KGOModule *loginModule = [KGO_SHARED_APP_DELEGATE() moduleForTag:self.loginPath];
        UIViewController *loginController = [loginModule modulePage:LocalPathPageNameHome params:nil];
        loginController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        loginController.modalPresentationStyle = UIModalPresentationFullScreen;
        [homescreen presentModalViewController:loginController animated:YES];
    }
}

- (void)logoutKurogoServer
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@"1" forKey:@"hard"];
    NSDictionary *userInfo = [_sessionInfo dictionaryForKey:@"user"];
    if (userInfo) {
        NSString *authority = [userInfo nonemptyStringForKey:@"authority"];
        if (authority) {
            [params setObject:authority forKey:@"authority"];
        }
    }

    _logoutRequest = [self requestWithDelegate:self
                                        module:self.loginPath
                                          path:@"logout"
                                       version:1
                                        params:params];
    [_logoutRequest connect];
}

- (BOOL)isUserLoggedIn
{
    NSDictionary *userInfo = [_sessionInfo dictionaryForKey:@"user"];
    if (userInfo) {
        NSString *authority = [userInfo nonemptyStringForKey:@"authority"];
        if (authority) {
            return YES;
        }
    }
    return NO;
}

- (NSDictionary *)sessionInfo
{
    return _sessionInfo;
}

- (void)requestSessionInfo
{
    if (!_sessionRequest) {
        DLog(@"requesting session info");
        for (NSHTTPCookie *aCookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
            if ([aCookie.domain rangeOfString:[self host]].location != NSNotFound) {
                DLog(@"%@", aCookie);
            }
        }
        
        _sessionRequest = [self requestWithDelegate:self
                                             module:self.loginPath
                                               path:@"session"
                                            version:1
                                             params:nil];
        _sessionRequest.expectedResponseType = [NSDictionary class];
        [_sessionRequest connect];
    }
}

- (BOOL)requestingSessionInfo
{
    return _sessionRequest != nil;
}

#pragma mark KGORequestDelegate


- (void)requestWillTerminate:(KGORequest *)request {
    if (request == _helloRequest) {
        _helloRequest = nil;
    } else if (request == _sessionRequest) {
        _sessionRequest = nil;
    } else if (request == _logoutRequest) {
        _logoutRequest = nil;
    } else if (request == _deviceRegistrationRequest) {
        _deviceRegistrationRequest = nil;
    } else if (request == _logoutRequest) {
        _logoutRequest = nil;
    }
}

- (void)request:(KGORequest *)request didFailWithError:(NSError *)error
{
    if (request == _deviceRegistrationRequest) {
        NSDictionary *userInfo = [error userInfo];
        // TODO: coordinate with kurogo server on error codes.
        // Unauthorized appears to be 4 right now, but 401 or 403 might
        // make more sense.
        NSString *title = [userInfo nonemptyStringForKey:@"title"];
        if ([title isEqualToString:@"Unauthorized"] && ![self isUserLoggedIn]) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:KGODidLoginNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(registerNewDeviceToken)
                                                         name:KGODidLoginNotification
                                                       object:nil];
        }
    }
    else if(request == _helloRequest) {
        [[NSNotificationCenter defaultCenter] postNotificationName:HelloRequestDidFailNotification object:self];
    }
}

- (void)request:(KGORequest *)request didReceiveResult:(id)result {
    if (request == _helloRequest) {
        NSArray *modules = [result arrayForKey:@"modules"];
        DLog(@"received modules from hello: %@", modules);
        [KGO_SHARED_APP_DELEGATE() loadModulesFromArray:modules local:NO];
        
        // get server time zone
        NSString *tzString = (NSString *)[result objectForKey:@"timezone"];
        if (tzString != nil) {
            NSTimeZone *tz = [NSTimeZone timeZoneWithName:tzString];
            [KGO_SHARED_APP_DELEGATE() setTimeZone:tz];
            DLog(@"Setting timezone to %@", tz);
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:HelloRequestDidCompleteNotification object:self];

    } else if (request == _sessionRequest) {
        [_sessionInfo release];
        _sessionInfo = [result retain];
        DLog(@"received session info: %@", _sessionInfo);

        if ([self isUserLoggedIn]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:KGODidLoginNotification object:self];
        }
        
    } else if (request == _deviceRegistrationRequest) {
        DLog(@"registered new device for push notifications: %@", result);
        NSString *deviceID = [result nonemptyStringForKey:@"device_id"];
        NSString *passKey = [result objectForKey:@"pass_key"];
        if ([passKey isKindOfClass:[NSNumber class]]) {
            passKey = [passKey description];
        }
        if (deviceID && [passKey isKindOfClass:[NSString class]]) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:deviceID forKey:KGOPushDeviceIDKey];
            [defaults setObject:passKey forKey:KGOPushDevicePassKeyKey];
            [defaults synchronize];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self name:KGODidLoginNotification object:nil];
        }
        
    } else if (request == _logoutRequest) {
        NSArray *cookies = [[[[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies] copy] autorelease];
        for (NSHTTPCookie *aCookie in cookies) {
           if ([[aCookie domain] rangeOfString:[self host]].location != NSNotFound) {
               [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:aCookie];
           }
        }
        
        [_sessionInfo release];
        _sessionInfo = nil;

        /*
        // TODO: decide how to handle data deletion.
        // e.g. keep track of data on a per-user basis?
        
        if ([[CoreDataManager sharedManager] deleteStore]) {
            DLog(@"deleted store");
        }
        */
        
        [[NSNotificationCenter defaultCenter] postNotificationName:KGODidLogoutNotification object:self];
    }
}

@end
