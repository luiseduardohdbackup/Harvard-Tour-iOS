#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "KGORequestManager.h"
#import "KGOSearchModel.h"

@class MapDataManager, KGOPlacemark;

@protocol MapDataManagerDelegate <NSObject>

@optional

- (void)browseIndexDidComplete:(MapDataManager *)dataManager;
- (void)mapDataManager:(MapDataManager *)dataManager didReceiveChildren:(NSArray *)children forCategory:(NSString *)categoryID;
- (void)mapDataManager:(MapDataManager *)dataManager didUpdatePlacemark:(KGOPlacemark *)placemark;

@end

@interface MapDataManager : NSObject <KGORequestDelegate> {
    
    KGORequest *_indexRequest;
    NSMutableDictionary *_categoryRequests;
    KGORequest *_detailRequest;
    KGORequest *_searchRequest;
    
    KGOPlacemark *_placemarkForDetailRequest;
}

@property(nonatomic, retain) ModuleTag *moduleTag;
@property(nonatomic, assign) id<MapDataManagerDelegate> delegate;
@property(nonatomic, assign) id<KGOSearchResultsHolder> searchDelegate;

- (void)requestBrowseIndex;
- (void)requestChildrenForCategory:(NSString *)categoryID;
- (void)requestDetailsForPlacemark:(KGOPlacemark *)placemark;

- (void)search:(NSString *)searchText;
- (void)searchNearby:(CLLocationCoordinate2D)coordinate;

@end
