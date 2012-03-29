#import "KGOSearchResultListTableView.h"
#import "KGOAppDelegate+ModuleAdditions.h"

@implementation KGOSearchResultListTableView

@synthesize items, resultsDelegate;

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<KGOSearchResult> theResult = [self.items objectAtIndex:indexPath.row];
    [self.resultsDelegate resultsHolder:self didSelectResult:theResult];
}

- (KGOTableCellStyle)tableView:(UITableView *)tableView styleForCellAtIndexPath:(NSIndexPath *)indexPath
{
    return KGOTableCellStyleSubtitle;
}

- (CellManipulator)tableView:(UITableView *)tableView manipulatorForCellAtIndexPath:(NSIndexPath *)indexPath
{
    id<KGOSearchResult> theResult = [self.items objectAtIndex:indexPath.row];
    NSString *title = theResult.title;
    NSString *subtitle = nil;
    if ([theResult respondsToSelector:@selector(subtitle)]) {
        subtitle = theResult.subtitle;
    }
    return [[^(UITableViewCell *cell) {
        cell.textLabel.text = title;
        cell.detailTextLabel.text = subtitle;
    } copy] autorelease];
}

// this shouldn't ever get called
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [_tableController tableView:self cellForRowAtIndexPath:indexPath];
}

#pragma mark KGOSearchResultsHolder

- (NSArray *)results
{
    return self.items;
}

- (void)receivedSearchResults:(NSArray *)results forSource:(NSString *)source
{
    self.items = results;
    [_tableController reloadDataForTableView:self];
}

#pragma mark KGODetailPagerController

- (NSInteger)pager:(KGODetailPager *)pager numberOfPagesInSection:(NSInteger)section {
    return self.items.count;
}

- (id<KGOSearchResult>)pager:(KGODetailPager *)pager contentForPageAtIndexPath:(NSIndexPath *)indexPath {
    return [self.items objectAtIndex:indexPath.row];
}

#pragma mark initialization boilerplate

- (id)init
{
    self = [super init];
    if (self) {
        _tableController = [[KGOTableController alloc] initWithTableView:self dataSource:self];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _tableController = [[KGOTableController alloc] initWithTableView:self dataSource:self];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _tableController = [[KGOTableController alloc] initWithTableView:self dataSource:self];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:style];
    if (self) {
        _tableController = [[KGOTableController alloc] initWithTableView:self dataSource:self];
    }
    return self;
}

- (void)dealloc
{
    [_tableController release];
    [super dealloc];
}

@end
