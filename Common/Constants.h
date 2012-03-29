#import <Foundation/Foundation.h>
#import "MITBuildInfo.h"

// this file is for constants that
// - need to be accessed all over the app
// - do not make sense as part of a module or library (common) group

extern NSString * const KUROGO_FRAMEWORK_NAME;
extern NSString * const KUROGO_FRAMEWORK_VERSION;

typedef NSString ModuleTag;

// the config strings for these are List, Grid, Portlet, Sidebar, and SplitView.
typedef enum {
    KGONavigationStyleUnknown,
    KGONavigationStyleTableView,
    KGONavigationStyleIconGrid,
    KGONavigationStylePortlet,
    // the following are not enabled for iPhone
    KGONavigationStyleTabletSidebar,
    KGONavigationStyleTabletSplitView,
    KGONavigationStyleTour
} KGONavigationStyle;

#pragma mark Valid names for handleLocalPath
// please add to this as necessary.
// Kurogo modules have a lot of pages in common and this list
// keeps track of all the view patterns we use
extern NSString * const LocalPathPageNameHome;
extern NSString * const LocalPathPageNameDetail;
extern NSString * const LocalPathPageNameSearch;
extern NSString * const LocalPathPageNameCategoryList;
extern NSString * const LocalPathPageNameItemList;
extern NSString * const LocalPathPageNameMapList;
extern NSString * const LocalPathPageNameBookmarks;
extern NSString * const LocalPathPageNameWebViewDetail; // this needs a better name -- too specific

#pragma mark Config keys
// list is not yet complete
extern NSString * const KGOAppConfigKeyModules;
extern NSString * const KGOAppConfigKeyServers;
extern NSString * const KGOAppConfigKeySocialMedia;

#pragma mark Global NSUserDefaults keys

extern NSString * const UnreadNotificationsKey;

#pragma mark App-wide notification names

extern NSString * const ModuleListDidChangeNotification;

extern NSString * const KGOUserPreferencesKey;
extern NSString * const KGOUserPreferencesDidChangeNotification;

extern NSString * const HelloRequestDidCompleteNotification;
extern NSString * const HelloRequestDidFailNotification;

extern NSString * const KGODidLogoutNotification;
extern NSString * const KGODidLoginNotification;

extern NSString * const CoreDataDidDeleteStoreNotification;
extern NSString * const KGOAppDidResetNotification;
extern NSString * const KGOServerDidChangeNotification;

#pragma mark Error domains



