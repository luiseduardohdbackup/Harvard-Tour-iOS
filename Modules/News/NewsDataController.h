#import <Foundation/Foundation.h>
#import "KGORequestManager.h"
#import "NewsModel.h"

// 2 hours
#define NEWS_CATEGORY_EXPIRES_TIME 7200.0

@class NewsDataController, NewsCategory, NewsStory;
@protocol KGOSearchResultsHolder;

@protocol NewsDataDelegate <NSObject>

@optional

- (void)dataController:(NewsDataController *)controller didRetrieveCategories:(NSArray *)categories;
- (void)dataController:(NewsDataController *)controller didRetrieveStories:(NSArray *)stories;

- (void)dataController:(NewsDataController *)controller didMakeProgress:(CGFloat)progress;

- (void)dataController:(NewsDataController *)controller didFailWithCategoryId:(NSString *)categoryId;
- (void)dataController:(NewsDataController *)controller didReceiveSearchResults:(NSArray *)results;

- (void)dataController:(NewsDataController *)controller didPruneStoriesForCategoryId:(NSString *)categoryId;

@end

@interface NewsDataController : NSObject <KGORequestDelegate> {
    
    NSMutableSet *_searchRequests;
    NSMutableArray *_currentStories; // stories displayed in the view
    NSArray *_currentCategories;
    
    NSMutableArray *_searchResults;
}

- (BOOL)requiresKurogoServer;

@property (nonatomic, retain) NSArray *currentCategories;
@property (nonatomic, retain) NSMutableArray *currentStories;

@property (nonatomic, retain) NewsCategory *currentCategory;
@property (nonatomic, retain) ModuleTag *moduleTag;
@property (nonatomic, assign) id<NewsDataDelegate> delegate;
@property (nonatomic, assign) id<KGOSearchResultsHolder> searchDelegate;

@property (nonatomic, copy) NSDate *feedListModifiedDate;



@property (nonatomic, retain) KGORequest *storiesRequest;
@property (nonatomic, retain) NSMutableSet *searchRequests;

// categories
- (void)fetchCategories; // fetches from core data first, then server if no results
- (NSArray *)latestCategories;
- (void)requestCategoriesFromServer;

// regular stories
- (void)fetchStoriesForCategory:(NSString *)categoryId
                        startId:(NSString *)startId;

- (void)requestStoriesForCategory:(NSString *)categoryId
                          afterId:(NSString *)afterId; // pass nil on refresh

//- (NSArray *)latestStories;
- (BOOL)canLoadMoreStories;

// bookmarks
- (void)fetchBookmarks;

// search
- (void)searchStories:(NSString *)searchTerms;
//- (void)fetchSearchResultsFromStore;
//- (NSArray *)latestSearchResults;


- (void)pruneStoriesForCategoryId:(NSString *)categoryId;


- (NSArray *)searchableCategories;
- (NSArray *)bookmarkedStories;

- (NewsStory *)storyWithDictionary:(NSDictionary *)storyDict;
- (NewsCategory *)categoryWithId:(NSString *)categoryId;
- (NewsCategory *)categoryWithDictionary:(NSDictionary *)categoryDict;

@end
