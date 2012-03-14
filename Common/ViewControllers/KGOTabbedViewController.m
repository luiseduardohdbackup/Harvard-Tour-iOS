#import "KGOTabbedViewController.h"
#import "KGODetailPageHeaderView.h"

@implementation KGOTabbedViewController

@synthesize tabs = _tabs, headerView = _headerView, tabViewContainer = _tabViewContainer;
@synthesize delegate;

- (void)reloadTabs
{
    NSInteger currentSelection = self.tabs.selectedTabIndex;
    NSString *selectedTitle = nil;
    UIImage *selectedImage = nil;
    if (currentSelection != NSNotFound) {
        selectedTitle = [self.tabs titleForTabAtIndex:currentSelection];
        selectedImage = [self.tabs imageForTabAtIndex:currentSelection];
    }
    currentSelection = NSNotFound;

    [self.tabs removeAllTabs];

    for (id item in [self.delegate itemsForTabbedControl:self.tabs]) {
        if ([item isKindOfClass:[NSString class]]) {
            if ([selectedTitle isEqualToString:item]) {
                currentSelection = self.tabs.numberOfTabs;
            }
            [self.tabs insertTabWithTitle:item atIndex:_tabs.numberOfTabs animated:NO];
        } else {
            if ([selectedImage isEqual:item]) {
                currentSelection = self.tabs.numberOfTabs;
            }
            [self.tabs insertTabWithImage:item atIndex:_tabs.numberOfTabs animated:NO];
        }
    }
    
    if (currentSelection != NSNotFound) {
        [self.tabs setSelectedTabIndex:currentSelection];
    }
    
    [self.tabs setNeedsLayout];
}

- (void)reloadTabContent {
    [self tabbedControl:_tabs didSwitchToTabAtIndex:[_tabs selectedTabIndex]];
}

- (void)tabbedControl:(KGOTabbedControl *)control didSwitchToTabAtIndex:(NSInteger)index {
    UIView *newView = [self.delegate tabbedControl:control containerViewAtIndex:index];
    if (newView) {
        for (UIView *oldView in _tabViewContainer.subviews) {
            [oldView removeFromSuperview];
        }
        [_tabViewContainer addSubview:newView];
    }
}

- (UIView *)tabbedControl:(KGOTabbedControl *)control containerViewAtIndex:(NSInteger)index {
    return nil;
}

- (NSArray *)itemsForTabbedControl:(KGOTabbedControl *)control {
    return nil;
}

- (void)headerViewFrameDidChange:(KGODetailPageHeaderView *)headerView
{
    CGRect frame = _tabs.frame;
    frame.origin.y = headerView.frame.size.height;
    _tabs.frame = frame;
    
    frame = _tabViewContainer.frame;
    frame.origin.y = _tabs.frame.origin.y + _tabs.frame.size.height;
    frame.size.height = self.view.bounds.size.height - frame.origin.y;
    _tabViewContainer.frame = frame;
}

#pragma mark -

- (id)init
{
    self = [super initWithNibName:@"KGOTabbedViewController" bundle:nil];
    if (self) {
        self.delegate = self;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.delegate = self;
    }
    return self;
}

- (void)dealloc
{
    self.tabs = nil;
    self.headerView = nil;
    self.tabViewContainer = nil;
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSBundle mainBundle] loadNibNamed:@"KGODetailPageHeaderView" owner:self options:nil];
    [self.view addSubview:self.headerView];

    self.headerView.delegate = self;
    self.tabs.delegate = self;
    
    for (id item in [self.delegate itemsForTabbedControl:_tabs]) {
        if ([item isKindOfClass:[NSString class]]) {
            [_tabs insertTabWithTitle:item atIndex:_tabs.numberOfTabs animated:NO];
        } else {
            [_tabs insertTabWithImage:item atIndex:_tabs.numberOfTabs animated:NO];
        }
    }
    
    if ([_tabs numberOfTabs]) {
        [_tabs setSelectedTabIndex:0];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];

    self.headerView = nil;
}

@end
