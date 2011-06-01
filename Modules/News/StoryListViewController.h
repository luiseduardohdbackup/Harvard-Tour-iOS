#import <UIKit/UIKit.h>
#import "NewsDataManager.h"
#import "KGOScrollingTabstrip.h"
#import "KGOSearchBar.h"
#import "KGOSearchDisplayController.h"
#import "StoryDetailViewController.h"
#import "KGOTableViewController.h"
#import "MITThumbnailView.h"

@class KGOSearchDisplayController;
@class NewsStory;

@interface StoryListViewController : KGOTableViewController <KGOSearchBarDelegate, NewsDataDelegate, KGOScrollingTabstripDelegate, KGOSearchDisplayDelegate, MITThumbnailDelegate> {
	UITableView *storyTable;
    NewsStory *featuredStory;
    NSArray *stories;
    NSArray *categories;
    NSString *activeCategoryId;
    BOOL activeCategoryHasMoreStories;
    
    NSArray *navButtons;
    
	// Nav Scroll View
	KGOScrollingTabstrip *navScrollView;
	UIButton *leftScrollButton;
	UIButton *rightScrollButton;  

	// Search bits
	NSInteger totalAvailableResults;
	KGOSearchBar *theSearchBar;
    KGOSearchDisplayController *searchController;
    NSInteger searchIndex;
	
	BOOL showingBookmarks;
	
    UIView *activityView;
    
    NSIndexPath *tempTableSelection;
    BOOL lastRequestSucceeded;
}

@property (nonatomic, assign) NSInteger totalAvailableResults;
@property (nonatomic, retain) NewsStory *featuredStory;
@property (nonatomic, retain) NSArray *stories;
@property (nonatomic, retain) NSArray *categories;
@property (nonatomic, retain) NSString *activeCategoryId;
@property (nonatomic, retain) NewsDataManager *dataManager;

- (void)showSearchBar;

- (void)pruneStories;
- (void)switchToCategory:(NSString *)category;
- (void)switchToBookmarks;

@end
