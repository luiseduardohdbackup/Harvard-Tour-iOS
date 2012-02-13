#import "PeopleHomeViewController.h"
#import "KGOAppDelegate+ModuleAdditions.h"
#import "Foundation+KGOAdditions.h"
#import "UIKit+KGOAdditions.h"
#import "KGOSearchBar.h"
#import "KGOSearchDisplayController.h"
#import "KGOTheme.h"
#import "KGOLabel.h"
#import "CoreDataManager.h"
#import "PeopleModule.h"
#import "PeopleModel.h"

@interface PeopleHomeViewController (Private)

- (void)promptToClearRecents;

@end


@implementation PeopleHomeViewController

@synthesize module, dataManager;
@synthesize federatedSearchTerms = _searchTerms,
searchTokens = _searchTokens,
searchController = _searchController,
searchBar = _searchBar,
federatedSearchResults;

#pragma mark view

- (void)viewDidLoad {
	[super viewDidLoad];
    
    self.title = @"People";

    _searchBar = [[KGOSearchBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, 44)];
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_searchBar.placeholder = NSLocalizedString(@"PEOPLE_SEARCH_PLACEHOLDER", @"Search");

    if (!_searchController) {
        _searchController = [[KGOSearchDisplayController alloc] initWithSearchBar:self.searchBar delegate:self contentsController:self];
    }

    [self.view addSubview:_searchBar];
    CGRect frame = CGRectMake(0.0, _searchBar.frame.size.height,
                              self.view.frame.size.width,
                              self.view.frame.size.height - _searchBar.frame.size.height);

	self.tableView = [self addTableViewWithFrame:frame style:UITableViewStyleGrouped];
    
    // search hint
    NSString *searchHints = NSLocalizedString(@"PEOPLE_SEARCH_TIP", @"Tip: You can search above by a person's first or last name or email address.");
	UIFont *hintsFont = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyBodyText];
    KGOLabel *hintsLabel = [KGOLabel multilineLabelWithText:searchHints font:hintsFont width:self.tableView.frame.size.width - 30];
    hintsLabel.frame = CGRectMake(15, 5, hintsLabel.frame.size.width, hintsLabel.frame.size.height);
    hintsLabel.textColor = [UIColor colorWithHexString:@"#404040"];
    UIView *hintsContainer = [[[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.tableView.frame.size.width,
                                                                       hintsLabel.frame.size.height + 10.0)] autorelease];
    
	[hintsContainer addSubview:hintsLabel];

	self.tableView.tableHeaderView = hintsContainer;
    
    if ([self.federatedSearchTerms length] > 0) {
		_searchBar.text = self.federatedSearchTerms;
        if (!self.federatedSearchResults) {
            [_searchController executeSearch:self.federatedSearchTerms params:nil];
        }
    }
    
    if (self.federatedSearchResults) {
        [_searchController setSearchResults:self.federatedSearchResults forModuleTag:self.module.tag];
        self.federatedSearchResults = nil;
    }
    
    if (!self.dataManager) {
        self.dataManager = [[[PeopleDataManager alloc] init] autorelease];
        self.dataManager.delegate = self;
        self.dataManager.moduleTag = self.module.tag;
        [self.dataManager fetchStaticContacts];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    _recentlyViewed = [[[KGOPersonWrapper fetchRecentlyViewed] mappedArrayUsingBlock:^id(id element) {
        [(KGOPersonWrapper *)element setModuleTag:self.module.tag];
        return element;
    }] retain];
	[self reloadDataForTableView:self.tableView];
}

#pragma mark - PeopleDataDelegate

- (void)dataManager:(PeopleDataManager *)dataManager didReceiveContacts:(NSArray *)contacts
{
    [_phoneDirectoryEntries release];
    _phoneDirectoryEntries = [contacts retain];
    [self reloadDataForTableView:self.tableView];
}

#pragma mark memory

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
	[_searchTerms release];
	[_searchTokens release];
	[_searchController release];
    [_phoneDirectoryEntries release];

    self.module = nil;
    self.dataManager.delegate = nil;
    self.dataManager = nil;
    
    [super dealloc];
}

#pragma mark -
#pragma mark Search methods

- (BOOL)searchControllerShouldShowSuggestions:(KGOSearchDisplayController *)controller {
    return YES;
}

- (NSArray *)searchControllerValidModules:(KGOSearchDisplayController *)controller {
    return [NSArray arrayWithObject:self.module.tag];
}

- (NSString *)searchControllerModuleTag:(KGOSearchDisplayController *)controller {
    return self.module.tag;
}

- (void)resultsHolder:(id<KGOSearchResultsHolder>)resultsHolder didSelectResult:(id<KGOSearchResult>)aResult {
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:aResult, @"person", nil];
    [KGO_SHARED_APP_DELEGATE() showPage:LocalPathPageNameDetail forModuleTag:self.module.tag params:params];
}

- (void)searchController:(KGOSearchDisplayController *)controller willHideSearchResultsTableView:(UITableView *)tableView {
    [[CoreDataManager sharedManager] saveData];
    [KGOPersonWrapper clearOldResults];
}

#pragma mark -
#pragma mark KGODetailPagerController

- (NSInteger)numberOfSections:(KGODetailPager *)pager {
    return 1;
}

- (NSInteger)pager:(KGODetailPager *)pager numberOfPagesInSection:(NSInteger)section {
    return _recentlyViewed.count;
}

- (id<KGOSearchResult>)pager:(KGODetailPager *)pager contentForPageAtIndexPath:(NSIndexPath *)indexPath {
    return [_recentlyViewed objectAtIndex:indexPath.row];
}

#pragma mark -
#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger numRows = 1;
    if (_recentlyViewed.count)
        numRows += 2;
    return numRows;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: // phone directory
            return _phoneDirectoryEntries.count;
        case 1: // recently viewed
            return _recentlyViewed.count;
        case 2: // clear recents
            return 1;
        default:
            return 0;
    }
}

- (NSArray *)tableView:(UITableView *)tableView viewsForCellAtIndexPath:(NSIndexPath *)indexPath {
    // making this button into a cell assumes that this table is being created as a grouped table view
    if (indexPath.section == 2) {
        UIFont *font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyNavListTitle];
        NSString *title = NSLocalizedString(@"PEOPLE_CLEAR_RECENTS", @"Clear Recents");
        CGSize size = [title sizeWithFont:font];
        
        // 20 is internal padding of grouped table view
        UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(floor((tableView.frame.size.width - 20 - size.width) / 2),
                                                                    0, size.width, tableView.rowHeight)] autorelease];
        label.textColor = [UIColor whiteColor];
        label.backgroundColor = [UIColor clearColor];
        label.font = font;
        label.text = title;
        return [NSArray arrayWithObject:label];
    }
    return nil;
}

- (CellManipulator)tableView:(UITableView *)tableView manipulatorForCellAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *title = nil;
    NSString *detailText = nil;
    NSString *accessoryTag = nil;
    UIColor *backgroundColor = nil;
    UIView *backgroundView = nil;
    UIView *selectedBackgroundView = nil;
    
    switch (indexPath.section) {
        case 0:
        {
            NSManagedObject *contact = [_phoneDirectoryEntries objectAtIndex:indexPath.row];
            if ([contact isKindOfClass:[PersonContactGroup class]]) {
                accessoryTag = KGOAccessoryTypeChevron; 
                backgroundColor = [[KGOTheme sharedTheme] backgroundColorForSecondaryCell];
                title = [(PersonContactGroup *)contact title];
            } else {
                PersonContact *personContact = (PersonContact *)contact;
                if ([personContact.type isEqualToString:@"phone"]){
                    detailText = personContact.subtitle;
                    accessoryTag = KGOAccessoryTypePhone; 
                    backgroundColor = [[KGOTheme sharedTheme] backgroundColorForSecondaryCell];
                    title = personContact.title;
                }
            }
            break;
        }
        case 1:
        {
            KGOPersonWrapper *person = [_recentlyViewed objectAtIndex:indexPath.row];
            title = [person title];
            detailText = [person subtitle];
            accessoryTag = KGOAccessoryTypeChevron;
            break;
        }
        case 2:
        {
            UIImage *backgroundImage = [[UIImage imageWithPathName:@"modules/people/redbutton2.png"] stretchableImageWithLeftCapWidth:10.0 topCapHeight:0.0];
            UIImage *selectedBackgroundImage = [[UIImage imageWithPathName:@"modules/people/redbutton2highlighted.png"] stretchableImageWithLeftCapWidth:10.0 topCapHeight:0.0];
            
            backgroundView = [[[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, tableView.rowHeight)] autorelease];
            [(UIImageView *)backgroundView setImage:backgroundImage];

            selectedBackgroundView = [[[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, tableView.rowHeight)] autorelease];
            [(UIImageView *)selectedBackgroundView setImage:selectedBackgroundImage];
            break;
        }
        default:
            break;
    }
    
    return [[^(UITableViewCell *cell) {
        cell.textLabel.text = title;
        cell.detailTextLabel.text = detailText;
        cell.accessoryView = [[KGOTheme sharedTheme] accessoryViewForType:accessoryTag];
        if (backgroundColor) {
            cell.backgroundColor = backgroundColor;
        }
        if (backgroundView) {
            cell.backgroundView = backgroundView;
        }
        if (selectedBackgroundView) {
            cell.selectedBackgroundView = selectedBackgroundView;
        }
    } copy] autorelease];
}


- (KGOTableCellStyle)tableView:(UITableView *)tableView styleForCellAtIndexPath:(NSIndexPath *)indexPath {
    return KGOTableCellStyleSubtitle;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return NSLocalizedString(@"PEOPLE_RECENTLY_VIEWED", @"Recently Viewed");
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
    switch (indexPath.section) {
        case 0: //Static numbers and groups
        {
            NSManagedObject *contact = [_phoneDirectoryEntries objectAtIndex:indexPath.row];
            if ([contact isKindOfClass:[PersonContact class]]) {
                PersonContact *personContact = (PersonContact *)contact;
                NSString *urlString = personContact.url;
                NSURL *externURL = [NSURL URLWithString:urlString];
                if ([[UIApplication sharedApplication] canOpenURL:externURL]) {
                    [[UIApplication sharedApplication] openURL:externURL];
                }
                
            } else if ([contact isKindOfClass:[PersonContactGroup class]]) {
                PersonContactGroup *contactGroup = (PersonContactGroup *)contact;
                NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:contactGroup, @"contactGroup", nil];
                [KGO_SHARED_APP_DELEGATE() showPage:LocalPathPageNameItemList forModuleTag:self.module.tag params:params];
            }
            
            break;
        }
        case 1: // recently viewed
        {
            KGOPersonWrapper *person = [_recentlyViewed objectAtIndex:indexPath.row];
            NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:person, @"person", self, @"pager", nil];
            [KGO_SHARED_APP_DELEGATE() showPage:LocalPathPageNameDetail forModuleTag:self.module.tag params:params];
            break;
        }
        case 2: // clear recents
            [self promptToClearRecents];
            break;
        default:
            break;
    }
    
}

#pragma mark -
#pragma mark Action sheet methods

- (void)promptToClearRecents
{
	UIActionSheet *sheet = [[[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"PEOPLE_CLEAR_RECENTS_CONFIRMATION", @"Clear Recents?")
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"COMMON_CANCEL", @"Cancel")
                                          destructiveButtonTitle:NSLocalizedString(@"PEOPLE_ACTION_SHEET_CLEAR", @"Clear")
                                               otherButtonTitles:nil] autorelease];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"PEOPLE_ACTION_SHEET_CLEAR", @"Clear")]) {
        [_recentlyViewed release];
        _recentlyViewed = nil;
		[KGOPersonWrapper clearRecentlyViewed];
		self.tableView.tableFooterView.hidden = YES;
		[self reloadDataForTableView:self.tableView];
		[self.tableView scrollRectToVisible:CGRectMake(0.0, 0.0, 1.0, 1.0) animated:YES];
	}
}

@end

