#import "Constants.h"

// local path names for handleLocalPath
NSString * const LocalPathPageNameHome = @"index";
NSString * const LocalPathPageNameDetail = @"detail";
NSString * const LocalPathPageNameSearch = @"search";
NSString * const LocalPathPageNameCategoryList = @"categories";
NSString * const LocalPathPageNameItemList = @"items";
NSString * const LocalPathPageNameMapList = @"map";
NSString * const LocalPathPageNameBookmarks = @"bookmarks";
NSString * const LocalPathPageNameWebViewDetail = @"webView";

// keys for NSUserDefaults dictionary go here (app preferences)
NSString * const UnreadNotificationsKey = @"UnreadNotifications";


// module tags
// TODO: get rid of all uses of these tags and use the tag given by the server
NSString * const HomeTag       = @"home";
NSString * const MapTag        = @"map";
NSString * const NewsTag       = @"news";
NSString * const PeopleTag     = @"people";
NSString * const PhotosTag     = @"photos";
NSString * const VideoModuleTag     = @"video";



// preferences

// TODO: clean up settings module and make all these go away
NSString * const FacebookGroupKey = @"FBGroup";
NSString * const FacebookGroupTitleKey = @"FBGroupTitle";
NSString * const TwitterHashTagKey = @"TwitterHashTag";

NSString * const MITNewsTwoFirstRunKey = @"MITNews2ClearedCachedArticles";

// notification names

NSString * const ModuleListDidChangeNotification = @"ModuleList";
NSString * const UserSettingsDidChangeNotification = @"UserSettingsChanged";

// core data entity names
NSString * const KGOPersonEntityName = @"KGOPerson";
NSString * const PersonContactEntityName = @"PersonContact";
NSString * const PersonOrganizationEntityName = @"PersonOrganization";
NSString * const PersonAddressEntityName = @"PersonAddress";

NSString * const KGOPlacemarkEntityName = @"KGOPlacemark";
NSString * const MapCategoryEntityName = @"KGOMapCategory";

NSString * const NewsStoryEntityName = @"NewsStory";
NSString * const NewsCategoryEntityName = @"NewsCategory";
NSString * const NewsImageEntityName = @"NewsImage";
NSString * const NewsImageRepEntityName = @"NewsImageRep";

NSString * const EmergencyNoticeEntityName = @"EmergencyNotice";
NSString * const EmergencyContactsSectionEntityName = @"EmergencyContactsSection";
NSString * const EmergencyContactEntityName = @"EmergencyContact";


// local paths for handleLocalPath
NSString * const LocalPathMapsSelectedAnnotation = @"annotation";


// resource names

NSString * const MITImageNameUpArrow = @"global/arrow-white-up.png";
NSString * const MITImageNameDownArrow = @"global/arrow-white-down.png";

// errors
NSString * const MapsErrorDomain = @"com.modolabs.Maps.ErrorDomain";
NSString * const ShuttlesErrorDomain = @"com.modolabs.Shuttles.ErrorDomain";
NSString * const JSONErrorDomain = @"com.modolabs.JSON.ErrorDomain";

