#import "VideoListViewController.h"
#import "Constants.h"
#import "VideoDetailViewController.h"
#import "CoreDataManager.h"
#import "VideoModule.h"
#import "KGOAppDelegate+ModuleAdditions.h"
#import "KGOTheme.h"
#import "ThumbnailTableViewCell.h"

static const NSInteger kVideoListCellThumbnailTag = 0x78;

#pragma mark Private methods

@interface VideoListViewController (Private)

- (void)requestVideosForActiveSection;

@end

@implementation VideoListViewController (Private)

- (void)requestVideosForActiveSection { 
    if (self.videoSections.count > self.activeSectionIndex) {
        NSString *section = [[self.videoSections objectAtIndex:self.activeSectionIndex] objectForKey:@"value"];
        __block VideoListViewController *blockSelf = self;
        [self.dataManager requestVideosForSection:section
                                     thenRunBlock:^(id result) { 
             if ([result isKindOfClass:[NSArray class]]) {
                 blockSelf.videos = result;
                 [blockSelf.tableView reloadData];
             }
         }];
    }
}

@end


@implementation VideoListViewController

@synthesize dataManager;
@synthesize navScrollView;
@synthesize videos;
@synthesize videoSections;
@synthesize activeSectionIndex;
@synthesize theSearchBar;
@synthesize cell = _cell;

@synthesize federatedSearchTerms, federatedSearchResults;

#pragma mark NSObject

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
	if (self) {
        self.activeSectionIndex = 0;
	}
	return self;
}

- (void)dealloc {
    [theSearchBar release];
    [videoSections release];
    [videos release];
    [navScrollView release];
    [dataManager release];

    self.federatedSearchTerms = nil;
    self.federatedSearchResults = nil;
    
    [super dealloc];
}

#pragma mark UIViewController

- (void)loadView {
    [super loadView];
    
    CGRect frame = CGRectMake(0, 0, self.view.bounds.size.width, 44);
    self.navScrollView = [[[KGOScrollingTabstrip alloc] initWithFrame:frame] autorelease];
    self.navScrollView.showsSearchButton = YES;
    self.navScrollView.delegate = self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 90.0f;
    
    __block VideoListViewController *blockSelf = self;
    [self.dataManager requestSectionsThenRunBlock:^(id result) {
        blockSelf.videoSections = (NSArray *)result;
        for (NSDictionary *sectionInfo in blockSelf.videoSections) {
            [blockSelf.navScrollView addButtonWithTitle:[sectionInfo objectForKey:@"title"]];
        }
        [blockSelf.navScrollView selectButtonAtIndex:blockSelf.activeSectionIndex];
        [blockSelf.navScrollView setNeedsLayout];
        [blockSelf requestVideosForActiveSection];
     }];
    self.navigationItem.title = [[KGO_SHARED_APP_DELEGATE() moduleForTag:self.dataManager.moduleTag] shortName];
    
    if (self.federatedSearchTerms || self.federatedSearchResults) {
        [self.navScrollView showSearchBarAnimated:NO];
        [self.navScrollView.searchController setActive:NO animated:NO];
        self.navScrollView.searchController.searchBar.text = self.federatedSearchTerms;
        
        if (self.federatedSearchResults) {
            [self.navScrollView.searchController setSearchResults:self.federatedSearchResults
                                                 forModuleTag:self.dataManager.moduleTag];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if ([self.dataManager bookmarkedVideos].count) {
        [self.navScrollView setShowsBookmarkButton:YES]; 
    } else {
        [self.navScrollView setShowsBookmarkButton:NO]; 
    }
    
    [self.navScrollView setNeedsLayout];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Save whatever thumbnail data we've downloaded.
    [[CoreDataManager sharedManager] saveData];
}

#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return self.videos.count;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    ThumbnailTableViewCell *cell = (ThumbnailTableViewCell *)[tableView dequeueReusableCellWithIdentifier:
                                                              [ThumbnailTableViewCell commonReuseIdentifier]];
    if (!cell) {
        [[NSBundle mainBundle] loadNibNamed:@"ThumbnailTableViewCell" owner:self options:nil];
        cell = _cell;
        cell.thumbnailSize = CGSizeMake(120, tableView.rowHeight);
    }

    Video *video = [self.videos objectAtIndex:indexPath.row];
    cell.thumbView.delegate = video;
    cell.titleLabel.text = video.title;
    cell.subtitleLabel.text = video.subtitle;
    
    cell.thumbView.imageURL = video.thumbnailURLString;
    cell.thumbView.imageData = video.thumbnailImageData;
    
    [cell.thumbView loadImage];
    
    return cell;
}

#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.videos.count > indexPath.row) {
        NSString *section = [[self.videoSections objectAtIndex:self.activeSectionIndex] objectForKey:@"value"];
        Video *video = [self.videos objectAtIndex:indexPath.row];
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                section, @"section", video, @"video", nil];
        [KGO_SHARED_APP_DELEGATE() showPage:LocalPathPageNameDetail
                               forModuleTag:self.dataManager.moduleTag
                                     params:params];
    }
}

// TODO: the scrolling tabstrip is not a section header.
// it is a control for selecting what table to show, and not logically part of the table below it.
// also it can mess with section headers in the search results table view.

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return self.navScrollView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return self.navScrollView.frame.size.height;
}

#pragma mark KGOScrollingTabstripDelegate

- (void)tabstrip:(KGOScrollingTabstrip *)tabstrip clickedButtonAtIndex:(NSUInteger)index {
    self.activeSectionIndex = index;
    [self requestVideosForActiveSection];
    if (self.videoSections.count > self.activeSectionIndex) {
        VideoModule *module = (VideoModule *)[KGO_SHARED_APP_DELEGATE() moduleForTag:self.dataManager.moduleTag];
        module.searchSection = [[self.videoSections objectAtIndex:self.activeSectionIndex] objectForKey:@"value"];
    }
}

- (void)tabstripBookmarkButtonPressed:(id)sender {
    showingBookmarks = YES;
    self.videos = [self.dataManager bookmarkedVideos];
    [self.tableView reloadData];
}

- (BOOL)tabstripShouldShowSearchDisplayController:(KGOScrollingTabstrip *)tabstrip
{
    return YES;
}

- (UIViewController *)viewControllerForTabstrip:(KGOScrollingTabstrip *)tabstrip
{
    return self;
}

#pragma mark KGOSearchDisplayDelegate
- (BOOL)searchControllerShouldShowSuggestions:(KGOSearchDisplayController *)controller {
    return NO;
}

- (NSArray *)searchControllerValidModules:(KGOSearchDisplayController *)controller {
    return [NSArray arrayWithObject:self.dataManager.moduleTag];
}

- (NSString *)searchControllerModuleTag:(KGOSearchDisplayController *)controller {
    return self.dataManager.moduleTag;
}

- (void)resultsHolder:(id<KGOSearchResultsHolder>)resultsHolder 
      didSelectResult:(id<KGOSearchResult>)aResult
{
    NSString *section = [[self.videoSections objectAtIndex:self.activeSectionIndex] objectForKey:@"value"];
    
    if ([aResult isKindOfClass:[Video class]]) {
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                section, @"section", aResult, @"video", nil];
        [KGO_SHARED_APP_DELEGATE() showPage:LocalPathPageNameDetail
                               forModuleTag:[aResult moduleTag]
                                     params:params];
    }
}

- (void)searchController:(KGOSearchDisplayController *)controller willHideSearchResultsTableView:(UITableView *)tableView
{
    self.federatedSearchTerms = nil;
    self.federatedSearchResults = nil;
    [self.navScrollView hideSearchBarAnimated:YES];
    [self.navScrollView selectButtonAtIndex:self.activeSectionIndex];
}

@end
