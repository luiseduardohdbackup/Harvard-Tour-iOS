#import <AudioToolbox/AudioToolbox.h>
#import "KGOAppDelegate+ModuleAdditions.h"
#import "KGOSpringboardViewController.h"
#import "HarvardNavigationController.h"
#import "KGOSidebarFrameViewController.h"
#import "KGOSplitViewController.h"
#import "KGOTheme.h"
#import "KGOModule+Factory.h"
#import "HomeModule.h"
#import "LoginModule.h"
#import "KGOSocialMediaController.h"
#import "AnalyticsWrapper.h"
#import "Foundation+KGOAdditions.h"
#import "KGORequestManager.h"
#import "KGONotification.h"
#import "KGOUserSettingsManager.h"
#import "CoreDataManager.h"
#import "KGOUserSettingsManager.h"

@interface KGOAppDelegate (PrivateModuleListAdditions)

- (void)addModule:(KGOModule *)module;

@end

@implementation KGOAppDelegate (PrivateModuleListAdditions)

- (void)addModule:(KGOModule *)aModule
{
    [_modules addObject:aModule];
    [_modulesByTag setObject:aModule forKey:aModule.tag];
    [aModule applicationDidFinishLaunching];
    if ([aModule isKindOfClass:[LoginModule class]]) {
        [[KGORequestManager sharedManager] setLoginPath:aModule.tag];
    }
    DLog(@"new module: %@", [aModule description]);
}

@end


@implementation KGOAppDelegate (ModuleListAdditions)

- (NSArray *)modules
{
    return _modules;
}

#pragma mark -
#pragma mark Shared resources

- (NSDictionary *)appConfig {
    if (!_appConfig) {
        NSString * mainFile = [[NSBundle mainBundle] pathForResource:@"Config" ofType:@"plist"];
        NSString * secretFile = [[NSBundle mainBundle] pathForResource:@"secret/Config" ofType:@"plist"];
        NSLog(@"%@", secretFile);        
        if (!secretFile) {
            _appConfig = [[NSDictionary alloc] initWithContentsOfFile:mainFile];
        } else {
            NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithContentsOfFile:mainFile];
            NSDictionary *overrides = [NSDictionary dictionaryWithContentsOfFile:secretFile];
            for (id aKey in [overrides allKeys]) {
                [mutableDict setObject:[overrides objectForKey:aKey] forKey:aKey];
            }
            _appConfig = [mutableDict copy];
        }
        DLog(@"current app config dictionary: %@", [_appConfig description]);
    }
    return _appConfig;
}

- (void)showNetworkActivityIndicator {
    networkActivityRefCount++;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    DLog(@"network indicator ++ %d", networkActivityRefCount);
}

- (void)hideNetworkActivityIndicator {
    if (networkActivityRefCount > 0) {
        networkActivityRefCount--;
        NSLog(@"network indicator -- %d", networkActivityRefCount);
    }
    if (networkActivityRefCount == 0) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }
}

#pragma mark Setup

- (void)loadModules {
    NSArray *moduleArray = [[self appConfig] arrayForKey:KGOAppConfigKeyModules];
    [self loadModulesFromArray:moduleArray local:YES];
}

// we need to do this separately since currently we have no way of
// functioning without the home screen
// TODO: make it possible to start from any module
- (void)loadHomeModule {
    NSDictionary *homeData = nil;
    NSArray *moduleArray = [[self appConfig] arrayForKey:KGOAppConfigKeyModules];
    for (NSDictionary *moduleData in moduleArray) {
        if ([[moduleData objectForKey:@"id"] isEqualToString:@"home"]) {
            homeData = moduleData;
            break;
        }
    }
    
    if (!homeData) {
        homeData = [NSDictionary dictionaryWithObjectsAndKeys:
                    @"HomeModule", @"class",
                    @"home", @"tag",
                    nil];
    }
    KGOModule *homeModule = [KGOModule moduleWithDictionary:homeData];
    _homeModule = homeModule;
    _homeModule.hasAccess = YES;
    [self addModule:_homeModule];
}

- (void)loadModulesFromArray:(NSArray *)moduleArray local:(BOOL)isLocal
{
    if (!isLocal) {
        moduleArray = [moduleArray sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            id homeConfig1 = [(NSDictionary *)obj1 objectForKey:@"home"];
            id homeConfig2 = [(NSDictionary *)obj2 objectForKey:@"home"];
            if ([homeConfig1 isKindOfClass:[NSDictionary class]]) {
                if ([homeConfig2 isKindOfClass:[NSDictionary class]]) {
                    return [[homeConfig1 objectForKey:@"order"] compare:[homeConfig2 objectForKey:@"order"]];
                }
                return NSOrderedAscending; // sort all non-showing modules to the end
            } else {
                if ([homeConfig2 isKindOfClass:[NSDictionary class]]) {
                    return NSOrderedDescending; // sort all non-showing modules to the end
                }
                return NSOrderedSame; // neither is showing so we don't care
            }
        }];
    }
    
    [[KGOUserSettingsManager sharedManager] updateModuleSettingsFromConfig:moduleArray];
    
    for (NSDictionary *moduleDict in moduleArray) {
        NSString *tag = [moduleDict nonemptyStringForKey:@"tag"];
        KGOModule *aModule = [self moduleForTag:tag];
        if (aModule) {
            [aModule updateWithDictionary:moduleDict];
            DLog(@"updating module: %@", [aModule description]);
        } else {
            aModule = [KGOModule moduleWithDictionary:moduleDict];
            if (aModule) {
                [self addModule:aModule];
                if (isLocal) {
                    aModule.hasAccess = YES;
                }
            }
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:ModuleListDidChangeNotification object:self];
}

- (void)loadNavigationContainer {
    if (!_appHomeScreen && !_appNavController) {    
        HomeModule *homeModule = (HomeModule *)_homeModule;
        UIViewController *homeVC = [homeModule modulePage:LocalPathPageNameHome params:nil];
        KGONavigationStyle navStyle = [self navigationStyle];
        switch (navStyle) {
            case KGONavigationStyleTabletSidebar:
            case KGONavigationStyleTabletSplitView:
            case KGONavigationStyleCustom:
            {
                _appHomeScreen = [homeVC retain];
                self.window.rootViewController = _appHomeScreen;
                break;
            }
            default:
            {
                UIImage *navBarImage = [[KGOTheme sharedTheme] backgroundImageForNavBar];
                if (navBarImage) {
                    _appNavController = [[UINavigationController alloc] initWithRootViewController:homeVC];
                    if ([_appNavController.navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
                        // for iOS 5
                        [_appNavController.navigationBar setBackgroundImage:navBarImage forBarMetrics:UIBarMetricsDefault];
                    } else {
                        [_appNavController release];
                        // for pre-iOS 5, use navigation controller wrapper to fake a custom nav bar
                        _appNavController = [[HarvardNavigationController alloc] initWithRootViewController:homeVC];
                    }

                } else {
                    _appNavController = [[UINavigationController alloc] initWithRootViewController:homeVC];
                }

                // set color of the nav bar buttons
                UIColor *tintColor = [[KGOTheme sharedTheme] tintColorForNavBar];
                if (tintColor) {
                    _appNavController.navigationBar.tintColor = tintColor;
                }

                _appNavController.view.backgroundColor = [[KGOTheme sharedTheme] backgroundColorForApplication];
                self.window.rootViewController = _appNavController;
                break;
            }
        }
        // TODO: see if there is a better place to put this
        NSString *pagePath = [NSString stringWithFormat:@"/%@/%@", homeModule.tag, LocalPathPageNameHome];
        [[AnalyticsWrapper sharedWrapper] trackPageview:pagePath];
    }
}

- (NSArray *)coreDataModelNames {
    if (!_modules) {
        [self loadModules];
    }
    NSMutableArray *modelNames = [NSMutableArray array];
    for (KGOModule *aModule in _modules) {
        NSArray *modelNamesForModule = [aModule objectModelNames];
        if (modelNamesForModule) {
            [modelNames addObjectsFromArray:modelNamesForModule];
        }
    }
    return modelNames;
}

- (void)resetAppDataAndSettings
{
    [[CoreDataManager sharedManager] deleteStore];

    // remove user defaults that interface relies on
    [[KGOUserSettingsManager sharedManager] wipeSettings];

    // these classes rely on data stored in NSUserDefaults
    [[KGOSocialMediaController sharedController] logoutAllServices];

    // remove all other manually accessed user defaults
    // TODO: figure out implications of deleting push notification token
    [NSUserDefaults resetStandardUserDefaults];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:KGOAppDidResetNotification
                                                        object:self];
}

#pragma mark Navigation

- (KGOModule *)moduleForTag:(NSString *)aTag {
    return [_modulesByTag objectForKey:aTag];
}

- (KGOModule *)visibleModule
{
    return _visibleModule;
}

// this should never be called on the home module.
- (BOOL)showPage:(NSString *)pageName forModuleTag:(ModuleTag *)moduleTag params:(NSDictionary *)params {
    BOOL didShow = NO;

    KGOModule *module = [self moduleForTag:moduleTag];
    
    if (module) {
        if (![module isLaunched]) {
            [module launch];
        }

        UIViewController *vc = [module modulePage:pageName params:params];
        if (!vc.title && [pageName isEqualToString:LocalPathPageNameHome]) {
            vc.title = module.shortName;
        }
        
        if (vc) {
            // storing mainly for calling viewWillAppear on modal transitions,
            // so assuming it's never deallocated when we try to access it
            _visibleViewController = vc;
            
            BOOL moduleDidChange = (_visibleModule != module);

            if (moduleDidChange) {
                [_visibleModule becomeHidden];
                [module becomeVisible];
                _visibleModule = module;
            }
            
            KGONavigationStyle navStyle = [self navigationStyle];
            switch (navStyle) {
                case KGONavigationStyleTabletSidebar:
                {
                    KGOSidebarFrameViewController *sidebarVC = (KGOSidebarFrameViewController *)_appHomeScreen;
                    [sidebarVC showViewController:vc];
                    break;
                }
                case KGONavigationStyleTabletSplitView:
                {
                    KGOSplitViewController *splitVC = (KGOSplitViewController *)_appHomeScreen;
                    if (splitVC.rightViewController.modalViewController) {
                        UIViewController *modalVC = splitVC.rightViewController.modalViewController;
                        if ([modalVC isKindOfClass:[UINavigationController class]]) {
                            [(UINavigationController *)modalVC pushViewController:vc animated:YES];
                        } else if (modalVC.navigationController) {
                            [modalVC.navigationController pushViewController:vc animated:YES];
                        }
                        
                    } else {
                        if (moduleDidChange) {
                            splitVC.isShowingModuleHome = YES;
                            splitVC.rightViewController = vc;
                        } else {
                            splitVC.isShowingModuleHome = NO;
                            [splitVC.rightViewController.navigationController pushViewController:vc animated:YES];
                        }
                    }
                    break;
                }
                default:
                {
                    // if the visible view controller is modal, push new view controllers on the modal nav controller.
                    UIViewController *homescreen = [self homescreen];
                    UIViewController *topVC = homescreen.navigationController.topViewController;
                    
                    if (topVC.modalViewController && [topVC.modalViewController isKindOfClass:[UINavigationController class]]) {
                        [(UINavigationController *)topVC.modalViewController pushViewController:vc animated:YES];
                        
                    } else {
                        [_appNavController pushViewController:vc animated:YES];
                    }
                    break;
                }
            }
            
            // tracking
            NSString *pagePath = [NSString stringWithFormat:@"/%@/%@", moduleTag, pageName];
            [[AnalyticsWrapper sharedWrapper] trackPageview:pagePath];
            
            didShow = YES;
        }
    }
    return didShow;
}

- (UIViewController *)visibleViewController {
    KGONavigationStyle navStyle = [self navigationStyle];
    switch (navStyle) {
        case KGONavigationStyleTabletSidebar:
        {
            return _appHomeScreen;
        }
        case KGONavigationStyleTabletSplitView:
        {
            KGOSplitViewController *splitVC = (KGOSplitViewController *)_appHomeScreen;
            return splitVC.rightViewController.navigationController.topViewController;
        }
        default:
        {
            UIViewController *homescreen = [self homescreen];
            return homescreen.navigationController.topViewController;
        }
    }
}

- (KGONavigationStyle)navigationStyle {
    if (_navigationStyle == KGONavigationStyleUnknown) {
        
        NSDictionary *homescreenDict = [[KGOTheme sharedTheme] homescreenConfig];
        NSString *style;
        
        style = [homescreenDict objectForKey:@"NavigationStyle"];
        
        if ([style isEqualToString:@"Grid"]) {
            _navigationStyle = KGONavigationStyleIconGrid;
            
        } else if ([style isEqualToString:@"List"]) {
            _navigationStyle = KGONavigationStyleTableView;
            
        } else if ([style isEqualToString:@"Portlet"]) {
            _navigationStyle = KGONavigationStylePortlet;
            
        } else if ([style isEqualToString:@"Custom"]) {
            _navigationStyle = KGONavigationStyleCustom;
            
        } else if ([style isEqualToString:@"Sidebar"] && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            _navigationStyle = KGONavigationStyleTabletSidebar;
            
        } else if ([style isEqualToString:@"SplitView"] && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            _navigationStyle = KGONavigationStyleTabletSplitView;
            
        } else {
            _navigationStyle = KGONavigationStyleIconGrid;
            
        }
    }
    return _navigationStyle;
}

- (UIViewController *)homescreen {
    if (_appNavController) {
        return [[_appNavController viewControllers] objectAtIndex:0];
    } else if (_appHomeScreen) {
        return _appHomeScreen;
    }
    return nil;
}

#pragma mark social media

- (void)loadSocialMediaController {
    if (!_modules) {
        [self loadModules];
    }
    NSMutableSet *mediaTypes = [NSMutableSet set];
    for (KGOModule *aModule in _modules) {
        NSSet *moreTypes = [aModule socialMediaTypes];
        if (moreTypes) {
            [mediaTypes unionSet:moreTypes];
            
            // TODO: make sure inputs are acceptable
            for (NSString *mediaType in moreTypes) {
                NSDictionary *settings = [aModule userInfoForSocialMediaType:mediaType];
                for (NSString *setting in [settings allKeys]) {
                    NSArray *options = [settings objectForKey:setting];
                    [[KGOSocialMediaController sharedController] addOptions:options forSetting:setting forMediaType:mediaType];
                }
            }
        }
    }
}

@end

#pragma mark -

@implementation KGOAppDelegate (URLHandlers)

// for iOS versions before 4.2
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    return [self application:application openURL:url sourceApplication:nil annotation:nil];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    
    DLog(@"attempting to handle URL %@\nsource application: %@\nannotation: %@",
         [url description], [sourceApplication description], [annotation description]);
    
    BOOL canHandle = NO;
    
    NSString *urlKey = nil;
    NSString *scheme = [url scheme];
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSArray *urlTypes = [infoDict objectForKey:@"CFBundleURLTypes"];
    for (NSDictionary *type in urlTypes) {
        urlKey = [type objectForKey:@"CFBundleURLName"];
        NSArray *schemes = [type objectForKey:@"CFBundleURLSchemes"];
        for (NSString *supportedScheme in schemes) {
            if ([supportedScheme isEqualToString:scheme]) {
                canHandle = YES;
                break;
            }
        }
        if (canHandle) {
            break;
        }
    }
    
    if (canHandle) {
        if ([urlKey isEqualToString:@"com.facebook"]) {
            canHandle = [self handleFacebookURL:url];
        } else {
            canHandle = [self handleInternalURL:url];
        }
        
    } else {
        DLog(@"%s couldn't handle url: %@", _cmd, url);
    }
    
    return canHandle;
}

- (NSString *)defaultURLScheme
{
    static NSString *internalScheme = nil;
    
    if (internalScheme == nil) {
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        NSArray *urlTypes = [infoDict objectForKey:@"CFBundleURLTypes"];
        NSString *bundleID = [infoDict objectForKey:@"CFBundleIdentifier"];
        
        for (NSDictionary *type in urlTypes) {
            NSString *urlKey = [type objectForKey:@"CFBundleURLName"];
            if ([urlKey isEqualToString:bundleID]) {
                NSArray *schemes = [type objectForKey:@"CFBundleURLSchemes"];
                if (schemes.count) {
                    internalScheme = [schemes objectAtIndex:0];
                }
                break;
            }
        }
    }
    
    return internalScheme;
}

- (BOOL)handleFacebookURL:(NSURL *)url
{
    // TODO: make sure this balances out
    DLog(@"is facebook started?");
    [[KGOSocialMediaController facebookService] startup];
    [[KGOSocialMediaController facebookService] parseCallbackURL:url];
    
    return [[KGOSocialMediaController facebookService] isSignedIn];
}

- (BOOL)handleInternalURL:(NSURL *)url {
    NSString *path = [url path];
    ModuleTag *moduleTag = [url host];
    KGOModule *module = [self moduleForTag:moduleTag];
    if ([path rangeOfString:@"/"].location == 0) {
        path = [path substringFromIndex:1];
    }
    
    // right now expecting URLs like mitmobile://people/search?Some%20Guy
    NSString *query = [[url query] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    return [module handleLocalPath:path query:query];
}

@end

#pragma mark -

@implementation KGOAppDelegate (Notifications)

- (void)registerForRemoteNotifications:(NSDictionary *)launchOptions {
    // Register for push notifications
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
	
	[self updateNotificationUI];
	//[self updateNotificationServer];
	
	// check if application was opened in response to a notofication
	NSDictionary *apnsDict = [launchOptions objectForKey:@"UIApplicationLaunchOptionsRemoteNotificationKey"];
	if (apnsDict) {
		KGONotification *notification = [KGONotification notificationWithDictionary:apnsDict];
        [_unreadNotifications addObject:notification];
        
        KGOModule *module = [self moduleForTag:notification.moduleName];
		[module handleRemoteNotification:notification];
        [module becomeVisible];
		NSLog(@"Application opened in response to notification=%@", notification);
	}	
}

- (void)updateNotificationUI {
	NSNumber *badgeCount = nil;
	int badgeCountInt = 0;
	
	NSMutableDictionary *notificationsByModule = [NSMutableDictionary dictionary];
	NSArray *notifications = [self unreadNotifications];
    
	for (KGONotification *notification in notifications) {
        badgeCount = [notificationsByModule objectForKey:notification.moduleName];
		if(badgeCount) {
			badgeCountInt = [badgeCount intValue] + 1;
		} else {
			badgeCountInt = 1;
		}
		
		[notificationsByModule setObject:[NSNumber numberWithInt:badgeCountInt] forKey:notification.moduleName];
	}
    
	// update the badge values for each tab item
	for (KGOModule *module in self.modules) {
		NSNumber *badgeValue = [notificationsByModule objectForKey:module.tag];
		NSString *badgeString = nil;
		if(badgeValue) {
			badgeString = [badgeValue description];
		}
		[module setBadgeValue:badgeString];
	}
	
	// update the total badge value for the application
	[UIApplication sharedApplication].applicationIconBadgeNumber = [notifications count];
}

- (NSMutableArray *)unreadNotifications {
    return _unreadNotifications;
}

- (void)fetchUnreadNotificationsFromCache {
    if (!_unreadNotifications) {
        _unreadNotifications = [[NSMutableArray alloc] init];
        for (NSDictionary *aDictionary in [[NSUserDefaults standardUserDefaults] objectForKey:UnreadNotificationsKey]) {
            [_unreadNotifications addObject:[KGONotification notificationWithDictionary:aDictionary]];
        }
    }
}

- (void)saveUnreadNotifications {
	NSMutableArray *arrayToSave = [NSMutableArray arrayWithCapacity:[_unreadNotifications count]];
    for (KGONotification *aNotification in _unreadNotifications) {
        [arrayToSave addObject:aNotification.userInfo];
    }
	[[NSUserDefaults standardUserDefaults] setObject:arrayToSave forKey:UnreadNotificationsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Notification delegation

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	DLog(@"Registered for push notifications. deviceToken == %@", deviceToken);
    KGORequestManager *requestManager = [KGORequestManager sharedManager];
    if (![requestManager.devicePushToken isEqualToData:deviceToken] || ![[KGORequestManager sharedManager] devicePushPassKey]) {
        requestManager.devicePushToken = deviceToken;
        [requestManager registerNewDeviceToken];
    }
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Failed to register for remote notifications. Error: %@", error);
}

// TODO: decide if we want to keep the following behavior, which only runs
// while the app is open and thus seems pretty redundant
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
	// vibrate the phone
	AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    
	KGONotification *notification = [KGONotification notificationWithDictionary:userInfo];
    [_unreadNotifications addObject:notification];
    
	// display the notification in an alert
    if (!showingAlertView) {
        showingAlertView = YES;
        
        NSString *appDisplayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        // TODO: figure out if it's really necessary to construct this alert view
        UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:appDisplayName
                                                             message:[[userInfo objectForKey:@"aps"] objectForKey:@"alert"]
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedString(@"CORE_CLOSE_ALERT_VIEW", @"Close")
                                                   otherButtonTitles:NSLocalizedString(@"CORE_VIEW_ALERT_VIEW", @"View"), nil] autorelease];
        [alertView show];
    }
}

#pragma mark -

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    KGONotification *latestNotification = [_unreadNotifications lastObject];
	
    KGOModule *module = [self moduleForTag:latestNotification.moduleName];
	[module handleRemoteNotification:latestNotification];
    
    NSString *viewTitle = NSLocalizedString(@"CORE_VIEW_ALERT_VIEW", @"View");
    
    if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:viewTitle]) {
        [module becomeVisible];
        // TODO: show the module
    }
    
    showingAlertView = NO;
}

@end
