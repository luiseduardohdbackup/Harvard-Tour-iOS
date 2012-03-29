#import <UIKit/UIKit.h>
#import "KGOTableViewController.h"
#import "NewsDataController.h"
#import "KGOScrollingTabstrip.h"
#import "KGOSearchBar.h"

@class KGOSearchDisplayController;
@class ThumbnailTableViewCell;
@class NewsStory;

@interface StoryListViewController : KGOTableViewController <KGOSearchBarDelegate,
NewsDataDelegate, 
KGOScrollingTabstripSearchDelegate> {
    
	IBOutlet UITableView *_storyTable;
    ThumbnailTableViewCell *_storyCell;
    
	// Nav Scroll View
	IBOutlet KGOScrollingTabstrip *_navScrollView;
	
    // progress bar
    IBOutlet UIView *_activityView;
    IBOutlet UILabel *_loadingLabel;
    IBOutlet UILabel *_lastUpdateLabel;
    IBOutlet UIProgressView *_progressView;
    
    NewsStory *featuredStory;
    NSString *activeCategoryId;
    
	// Search bits
	NSInteger totalAvailableResults;
	KGOSearchBar *theSearchBar;
    //KGOSearchDisplayController *searchController;
    NSInteger searchIndex;
	
	BOOL showingBookmarks;
}

@property (nonatomic, retain) IBOutlet ThumbnailTableViewCell *cell;

@property (nonatomic, retain) NewsStory *featuredStory;
@property (nonatomic, retain) NSArray *stories;
@property (nonatomic, retain) NSArray *categories;
@property (nonatomic, retain) NSString *activeCategoryId;
@property (nonatomic, retain) NewsDataController *dataManager;

@property (nonatomic, retain) NSArray *federatedSearchResults;
@property (nonatomic, retain) NSString *federatedSearchTerms;

//- (void)showSearchBar;
- (void)switchToCategory:(NSString *)category;
- (void)switchToBookmarks;

@end
