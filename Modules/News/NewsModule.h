#import <Foundation/Foundation.h>
#import "KGOModule.h"
#import "NewsDataController.h"

@interface NewsModule : KGOModule <NewsDataDelegate> {
    NSInteger totalResults;
    //id<KGOSearchResultsHolder> *searchDelegate;
    NewsDataController *_dataManager;
    NSDictionary *_payload;
    NSString *_searchText;
}

@property (readonly) NewsDataController *dataManager;

@end
