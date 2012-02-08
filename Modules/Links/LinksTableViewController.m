#import "IconGrid.h"
#import "MITThumbnailView.h"
#import "LinksTableViewController.h"
#import "KGOAppDelegate+ModuleAdditions.h"
#import "KGOLabel.h"
#import "KGOTheme.h"
#import "UIKit+KGOAdditions.h"

#define OVERLAY_TAG 233

@interface LinksTableViewController (Private)

- (void)layoutSpringboard;

@end

@implementation LinksTableViewController
@synthesize request;
@synthesize loadingIndicator;
@synthesize loadingView;

- (id)initWithModuleTag: (ModuleTag *) aModuleTag
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        // Custom initialization
        
        self.title = NSLocalizedString(@"Links", nil);
        if ((nil == linksArray) || (nil == description))
            [self addLoadingView];
        
        moduleTag = [aModuleTag retain];
            
    }
    return self;
}

- (void) addLoadingView {
    
    self.loadingView = [[[UIView alloc] initWithFrame:self.view.bounds] autorelease];
    loadingView.backgroundColor = [UIColor whiteColor];
    loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.loadingIndicator = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    [loadingIndicator startAnimating];
    loadingIndicator.center = self.loadingView.center;

    [loadingView addSubview:loadingIndicator];
    [self.view addSubview:loadingView];
}

- (void) removeLoadingView {
    [self.loadingIndicator stopAnimating];
    [self.loadingView removeFromSuperview];
}


- (void)dealloc
{
    [moduleTag release];
    [linksArray dealloc];
    [description dealloc];
    [descriptionFooter release];
    self.loadingIndicator = nil;
    self.loadingView = nil;
    iconGrid.delegate = nil;
    [iconGrid release];
    [scrollView release];
    [descriptionLabel release];
    [descriptionFooterLabel release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)viewDidUnload
{
    linksArray = nil;
    description = nil;
    descriptionFooter = nil;
    
    [descriptionLabel release];
    descriptionLabel = nil;
    
    [descriptionFooterLabel release];
    descriptionFooterLabel = nil;
    
    [iconGrid release];
    iconGrid = nil;
    
    [scrollView release];
    scrollView = nil;
    
    self.loadingIndicator = nil;
    self.loadingView = nil;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

/*
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}*/

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    
    if (nil != linksArray) {
        return 1;
    }
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if (nil != linksArray)
        return [linksArray count];
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"CellForLinks";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    NSString * linkTitle = [(NSDictionary *)[linksArray objectAtIndex:indexPath.row] objectForKey:@"title"];
    NSString * linkSubtitle = [(NSDictionary *)[linksArray objectAtIndex:indexPath.row] objectForKey:@"subtitle"];
    
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.lineBreakMode = UILineBreakModeTailTruncation;
    cell.textLabel.text = linkTitle;
    cell.textLabel.font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyNavListTitle]; 
    cell.textLabel.textColor = [[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertyNavListTitle];
    
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.lineBreakMode = UILineBreakModeTailTruncation;
    cell.detailTextLabel.text = linkSubtitle;
    cell.detailTextLabel.font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyNavListSubtitle];
    cell.detailTextLabel.textColor = [[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertyNavListSubtitle];
    
    if([(NSDictionary *)[linksArray objectAtIndex:indexPath.row] objectForKey:@"url"]) {
        cell.accessoryView = [[KGOTheme sharedTheme] accessoryViewForType:KGOAccessoryTypeExternal];
    } else {
        cell.accessoryView = [[KGOTheme sharedTheme] accessoryViewForType:KGOAccessoryTypeChevron];
    }
    [cell applyBackgroundThemeColorForIndexPath:indexPath tableView:tableView];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // TODO help! is there any good way to know
    // how much space the labels in the cell have?
    CGFloat cellWidth = tableView.frame.size.width - 64;
    UIFont *titleFont = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyNavListTitle];
    UIFont *subtitleFont = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyNavListSubtitle];
    NSString * linkTitle = [(NSDictionary *)[linksArray objectAtIndex:indexPath.row] objectForKey:@"title"];
    NSString * linkSubtitle = [(NSDictionary *)[linksArray objectAtIndex:indexPath.row] objectForKey:@"subtitle"];
    
    CGSize titleSize = [linkTitle sizeWithFont:titleFont constrainedToSize:CGSizeMake(cellWidth, 250)];
    CGSize subtitleSize = [linkSubtitle sizeWithFont:subtitleFont constrainedToSize:CGSizeMake(cellWidth, 250)];
    
    CGFloat height = titleSize.height + subtitleSize.height + 10;
    return MAX(height, tableView.rowHeight);
}

- (void)openLink:(NSDictionary *)linkDict {
    NSURL *url = nil;
    NSString *urlString = [linkDict objectForKey:@"url"];
    NSString *groupString = [linkDict objectForKey:@"group"];
    NSString *title = [linkDict objectForKey:@"title"];
    
    if (urlString) {
        url = [NSURL URLWithString:urlString];
        
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url];
        }
    } else if (groupString) {
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params setObject:groupString forKey:@"group"];
        [params setObject:title forKey:@"title"];
        
        [KGO_SHARED_APP_DELEGATE() showPage:LocalPathPageNameItemList forModuleTag:moduleTag params:params];
    }    
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self openLink:[linksArray objectAtIndex:indexPath.row]];        
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark KGORequestDelegate

- (void)requestWillTerminate:(KGORequest *)request {
    self.request = nil;
}


- (void)request:(KGORequest *)request didReceiveResult:(id)result {
    self.request = nil;
    
    DLog(@"%@", [result description]);
    
    description = [[result objectForKey:@"description"] retain];
    linksArray = [[result objectForKey:@"links"] retain];
    descriptionFooter = [[result objectForKey:@"description_footer"] retain];
    
    NSString * displayTypeString = [result objectForKey:@"displayType"];    
    if ([displayTypeString isEqualToString:@"list"])
        displayType = LinksDisplayTypeList;
    else if([displayTypeString isEqualToString:@"springboard"])
        displayType = LinksDisplayTypeSpringboard;
    else
        displayType = LinksDisplayTypeList; // default
    
    // Display as TableView
    if (displayType == LinksDisplayTypeList) {
        self.tableView.tableHeaderView = [self viewForTableHeader];
        self.tableView.tableFooterView = [self viewForTableFooter];
        [self.tableView reloadData];
    } else {
        [self.tableView removeFromSuperview];
        [self layoutSpringboard];
    }

    [self removeLoadingView];
    
}

- (void)layoutSpringboard {
    
    if (!scrollView) {
        scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
        [self.view addSubview:scrollView];
    }
    
    if (description && description.length) {
        if (!descriptionLabel) {
            descriptionLabel = [[KGOLabel alloc] initWithFrame:CGRectMake(10, 0, self.view.frame.size.width-20, 300)];
            descriptionLabel.numberOfLines = 0;
            descriptionLabel.font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyPageSubtitle];
            descriptionLabel.textColor = [[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertyPageSubtitle];
            descriptionLabel.backgroundColor = [UIColor clearColor];
            [scrollView addSubview:descriptionLabel];
        }
        
        CGSize descriptionSize = [description sizeWithFont:descriptionLabel.font constrainedToSize:descriptionLabel.frame.size];
        CGRect descriptionFrame = descriptionLabel.frame;
        descriptionFrame.size = descriptionSize;
        descriptionLabel.frame = descriptionFrame;
        descriptionLabel.text = description;
    }
    
    if (descriptionFooter && descriptionFooter.length) {
        if (!descriptionFooterLabel) {
            descriptionFooterLabel = [[KGOLabel alloc] initWithFrame:CGRectMake(10, 0, self.view.frame.size.width-20, 300)];
            descriptionFooterLabel.numberOfLines = 0;
            descriptionFooterLabel.font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyPageSubtitle];
            descriptionFooterLabel.textColor = [[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertyPageSubtitle];
            descriptionFooterLabel.backgroundColor = [UIColor clearColor];
            [scrollView addSubview:descriptionFooterLabel];
        }
        
        CGSize descriptionSize = [descriptionFooter sizeWithFont:descriptionFooterLabel.font constrainedToSize:descriptionFooterLabel.frame.size];
        CGRect descriptionFooterFrame = descriptionFooterLabel.frame;
        descriptionFooterFrame.origin.y = scrollView.frame.size.height - descriptionSize.height;
        descriptionFooterFrame.size = descriptionSize;
        descriptionFooterLabel.frame = descriptionFooterFrame;
        descriptionFooterLabel.text = descriptionFooter;
    }
    
    if(!iconGrid) {
        iconGrid = [[IconGrid alloc] initWithFrame:CGRectMake(0, descriptionLabel.frame.size.height, scrollView.frame.size.width, scrollView.frame.size.height - descriptionLabel.frame.size.height - descriptionFooterLabel.frame.size.height)];
        iconGrid.delegate = self;
        [scrollView addSubview:iconGrid];
    }
    
    
    NSMutableArray *icons = [NSMutableArray array];
    
    for (NSInteger index=0; index < linksArray.count; index++) {
        NSDictionary *linkDict = [linksArray objectAtIndex:index];
                                  
        UIControl *iconView = [[[UIControl alloc] initWithFrame:CGRectMake(0, 0, 80, 120)] autorelease];
        
        MITThumbnailView *thumbnailView = [[[MITThumbnailView alloc] initWithFrame:CGRectMake(0, 0, 80, 80)] autorelease];
        thumbnailView.userInteractionEnabled = NO;
        NSString *iconURL = [linkDict objectForKey:@"iconURL"];
        thumbnailView.imageURL = [iconURL stringByReplacingOccurrencesOfString:@" " withString:@"%20"];            
        [thumbnailView loadImage];
        [iconView addSubview:thumbnailView];
        
        KGOLabel *label = [[[KGOLabel alloc] initWithFrame:CGRectMake(0, 80, 80, 40)] autorelease];
        label.font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertySmallPrint];
        label.textColor = [[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertySmallPrint];
        label.numberOfLines = 2;
        label.lineBreakMode = UILineBreakModeMiddleTruncation;
        label.text = [linkDict objectForKey:@"title"];
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = UITextAlignmentCenter;
        label.userInteractionEnabled = NO;
        
        [iconView addSubview:label];
        iconView.tag = index;
        [iconView addTarget:self action:@selector(touchStart:) forControlEvents:UIControlEventTouchDown];
        [iconView addTarget:self action:@selector(touchEnd:) forControlEvents:UIControlEventTouchUpOutside];
        [iconView addTarget:self action:@selector(linkSelected:) forControlEvents:UIControlEventTouchUpInside];
        [icons addObject:iconView];
    }
    iconGrid.icons = icons;
}

#pragma mark - Table header


- (UIView *)viewForTableHeader
{
    if (!headerView && description && description.length) {
        // information in header
        
        UIFont *font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyPageSubtitle];
        KGOLabel *nameLabel = [KGOLabel multilineLabelWithText:description font:font width:self.tableView.frame.size.width - 10];
        nameLabel.frame = CGRectMake(10, 10, nameLabel.frame.size.width, nameLabel.frame.size.height);
        
        UIView *header = [[[UIView alloc] initWithFrame:CGRectMake(5, 20, self.tableView.frame.size.width, nameLabel.frame.size.height + 14)] autorelease];
        [header addSubview:nameLabel];
        
        headerView = header;
    }
    
    return headerView;
}

- (UIView *)viewForTableFooter
{
    if (!footerView && descriptionFooter && descriptionFooter.length) {
        // information in header
        
        UIFont *font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyPageSubtitle];
        KGOLabel *nameLabel = [KGOLabel multilineLabelWithText:descriptionFooter font:font width:self.tableView.frame.size.width - 10];
        nameLabel.frame = CGRectMake(10, 10, nameLabel.frame.size.width, nameLabel.frame.size.height);
        
        UIView *footer = [[[UIView alloc] initWithFrame:CGRectMake(5, 20, self.tableView.frame.size.width, nameLabel.frame.size.height + 14)] autorelease];
        [footer addSubview:nameLabel];
        
        footerView = footer;
    }
    
    return footerView;
}

#pragma mark - IconGrid delegate

- (void)iconGridFrameDidChange:(IconGrid *)aIconGrid {
    scrollView.contentSize = CGSizeMake(aIconGrid.frame.size.width, aIconGrid.frame.origin.y + aIconGrid.frame.size.height);
}

#pragma mark - icon grid touches

- (void)touchStart:(id)sender {
    UIView *buttonView = sender;
    UIView *overlay = [[[UIView alloc] initWithFrame:buttonView.bounds] autorelease];
    overlay.userInteractionEnabled = NO;
    overlay.backgroundColor = [UIColor blackColor];
    overlay.alpha = 0.1;
    overlay.tag = OVERLAY_TAG;
    [buttonView addSubview:overlay];
}

- (void)touchEnd:(id)sender {
    UIView *buttonView = sender;
    UIView *overlay = [buttonView viewWithTag:OVERLAY_TAG];
    [overlay removeFromSuperview];
}

- (void)linkSelected:(id)sender {
    UIView *buttonView = sender;
    UIView *overlay = [buttonView viewWithTag:OVERLAY_TAG];
    [overlay removeFromSuperview];
    
    [self openLink:[linksArray objectAtIndex:buttonView.tag]];
}
@end
