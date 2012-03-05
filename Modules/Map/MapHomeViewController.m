#import "MapHomeViewController.h"
#import "MapCategoryListViewController.h"
#import "KGOAppDelegate+ModuleAdditions.h"
#import "MapModule.h"
#import "MapModel.h"
#import "MapSettingsViewController.h"
#import "KGOBookmarksViewController.h"
#import "KGOTheme.h"
#import "Foundation+KGOAdditions.h"
#import "CoreDataManager.h"
#import "MapKit+KGOAdditions.h"
#import "UIKit+KGOAdditions.h"
#import "KGOToolbar.h"
#import "KGOSidebarFrameViewController.h"
#import "KGOSegmentedControl.h"
#import <QuartzCore/QuartzCore.h>

@implementation MapHomeViewController

@synthesize searchTerms, searchOnLoad, searchParams, mapModule, selectedPopover;
@synthesize mapView;

- (void)mapTypeDidChange:(NSNotification *)aNotification {
    self.mapView.mapType = [[aNotification object] integerValue];
}

- (void)setupToolbarButtons {
    _infoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_infoButton setImage:[UIImage imageWithPathName:@"modules/map/map-button-info"] forState:UIControlStateNormal];
    
    _locateUserButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_locateUserButton setImage:[UIImage imageWithPathName:@"modules/map/map-button-location"] forState:UIControlStateNormal];

    _browseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_browseButton setImage:[UIImage imageWithPathName:@"modules/map/map-button-browse"] forState:UIControlStateNormal];
    
    _bookmarksButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_bookmarksButton setImage:[UIImage imageWithPathName:@"modules/map/map-button-favorites"] forState:UIControlStateNormal];

    _settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_settingsButton setImage:[UIImage imageWithPathName:@"modules/map/map-button-settings"] forState:UIControlStateNormal];
        
    UIImage *normalImage = [UIImage imageWithPathName:@"common/toolbar-button"];
    UIImage *pressedImage = [UIImage imageWithPathName:@"common/toolbar-button-pressed"];
    CGRect frame = CGRectZero;
    if (normalImage) {
        frame.size = normalImage.size;
    } else {
        frame.size = CGSizeMake(42, 31);
    }

    NSArray *buttons = [NSArray arrayWithObjects:_infoButton, _locateUserButton, _browseButton, _bookmarksButton, _settingsButton, nil];
    for (UIButton *aButton in buttons) {
        aButton.frame = frame;
        [aButton setBackgroundImage:normalImage forState:UIControlStateNormal];
        [aButton setBackgroundImage:pressedImage forState:UIControlStateHighlighted];
        [aButton addTarget:self action:@selector(toolbarButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    
	indoorMode = NO;
	NSArray *items = nil;
	UIBarButtonItem *spacer = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease];
    
    [_browseBarButtonItem release];
    _browseBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_browseButton];

    [_bookmarksBarButtonItem release];
    _bookmarksBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_bookmarksButton];

    [_settingsBarButtonItem release];
    _settingsBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_settingsButton];
    
	if (indoorMode) {
		items = [NSArray arrayWithObjects:
                 [[[UIBarButtonItem alloc] initWithCustomView:_infoButton] autorelease], spacer,
                 _browseBarButtonItem, spacer,
                 _bookmarksBarButtonItem, spacer,
                 _settingsBarButtonItem,
                 nil];
	} else {
		items = [NSArray arrayWithObjects:
                 [[[UIBarButtonItem alloc] initWithCustomView:_locateUserButton] autorelease], spacer,
                 _browseBarButtonItem, spacer,
                 _bookmarksBarButtonItem, spacer,
                 _settingsBarButtonItem,
                 nil];
	}
    
    if ([CLLocationManager respondsToSelector:@selector(authorizationStatus)]) { // 4.2 and above only
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) {
            _locateUserButton.enabled = NO;
        }
    }
    
	_bottomBar.items = items;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (_mapBorder) {
        _mapBorder.layer.cornerRadius = 4;
    }
    
    self.title = self.mapModule.shortName;

    self.mapView.mapType = [[NSUserDefaults standardUserDefaults] integerForKey:MapTypePreference];
    [self.mapView centerAndZoomToDefaultRegion];
    if (self.annotations.count) { // these would have been set before _mapView was set up
        [self.mapView addAnnotations:self.annotations];
        // TODO: rewrite regionForAnnotations: to return a success value
        MKCoordinateRegion region = [MapHomeViewController regionForAnnotations:self.annotations restrictedToClass:NULL];
        if (region.center.latitude && region.center.longitude) {
            self.mapView.region = region;
        }
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mapTypeDidChange:) name:MapTypePreferenceChanged object:nil];

    [self setupToolbarButtons];
    if (_toolbarDropShadow) {
        UIImage *image = [[KGOTheme sharedTheme] backgroundImageForSearchBarDropShadow];
        if (image) {
            _toolbarDropShadow.image = image;
        }
    }

    // set up search bar
    _searchBar.placeholder = NSLocalizedString(@"MAP_SEARCH_PLACEHOLDER", @"Map Search Placeholder");
	_searchController = [[KGOSearchDisplayController alloc] initWithSearchBar:_searchBar delegate:self contentsController:self];
    if (self.searchTerms) {
        _searchBar.text = self.searchTerms;
    }
    if (self.searchOnLoad) {
        [_searchController executeSearch:self.searchTerms params:self.searchParams];
        [_searchController reloadSearchResultsTableView];
    }
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    [_toolbarDropShadow release];
    _toolbarDropShadow = nil;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (_placemarkInfoRequest) {
        [_placemarkInfoRequest cancel];
    }
    
    [_pendingPlacemark release];
    self.mapView.delegate = nil;
    self.mapView = nil;
    [_annotations release];
	[_searchController release];
    [_toolbarDropShadow release];
    [super dealloc];
}

- (NSArray *)annotations {
    return _annotations;
}

- (void)setAnnotations:(NSArray *)annotations {
    [_annotations release];
    _annotations = [annotations retain];

    if (self.mapView) {
        [self.mapView removeAnnotations:self.mapView.annotations];
        if (_annotations) {
            [self.mapView addAnnotations:_annotations];
        }
    }
}

#pragma mark KGORequest

- (void)requestWillTerminate:(KGORequest *)request
{
    _placemarkInfoRequest = nil;
}

- (void)request:(KGORequest *)request didReceiveResult:(id)result
{
    if (_pendingPlacemark) {
        NSString *incomingID = [result nonemptyStringForKey:@"id"];
        if ([incomingID isEqualToString:_pendingPlacemark.identifier]) {
            [_pendingPlacemark updateWithDictionary:result];
            DLog(@"%@", _pendingPlacemark);
            [self.mapView removeAnnotations:[self.mapView annotations]];
            [self.mapView addAnnotation:_pendingPlacemark];
        }
        [_pendingPlacemark release];
        _pendingPlacemark = nil;
    }
}

#pragma mark -

- (void)toolbarButtonPressed:(id)sender
{
    if (sender == _infoButton) {
        [self infoButtonPressed];
    } else if (sender == _locateUserButton) {
        [self locateUserButtonPressed];
    } else if (sender == _browseButton) {
        [self browseButtonPressed];
    } else if (sender == _bookmarksButton) {
        [self bookmarksButtonPressed];
    } else if (sender == _settingsButton) {
        [self settingsButtonPressed];
    }
}

- (IBAction)infoButtonPressed {
	
}

- (IBAction)browseButtonPressed {
	MapCategoryListViewController *categoryVC = [[[MapCategoryListViewController alloc] init] autorelease];
    categoryVC.dataManager = self.mapModule.dataManager;
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"topLevel = YES"];
    NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"sortOrder" ascending:YES]];
    categoryVC.listItems = [[CoreDataManager sharedManager] objectsForEntity:MapCategoryEntityName
                                                           matchingPredicate:pred
                                                             sortDescriptors:sortDescriptors];
    
    UINavigationController *navC = [[[UINavigationController alloc] initWithRootViewController:categoryVC] autorelease];
    navC.modalPresentationStyle = UIModalPresentationFormSheet;
    navC.navigationBar.barStyle = [[KGOTheme sharedTheme] defaultNavBarStyle];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UIBarButtonItem *item = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                               target:self
                                                                               action:@selector(dismissModalViewControllerAnimated:)] autorelease];
        categoryVC.navigationItem.rightBarButtonItem = item;
        [self presentModalViewController:navC animated:YES];

    } else {
        [self dismissPopoverAnimated:YES];
        self.selectedPopover = [[[UIPopoverController alloc] initWithContentViewController:navC] autorelease];
        // 320 and 600 are the minimum width and maximum height specified in the documentation
        self.selectedPopover.popoverContentSize = CGSizeMake(320, 600);
        self.selectedPopover.delegate = self;
        [self.selectedPopover presentPopoverFromBarButtonItem:_browseBarButtonItem
                                     permittedArrowDirections:UIPopoverArrowDirectionUp
                                                     animated:YES];
    }
}

- (IBAction)bookmarksButtonPressed {
    
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"bookmarked = YES"];
    NSArray *array = [[CoreDataManager sharedManager] objectsForEntity:KGOPlacemarkEntityName matchingPredicate:pred];
    KGOBookmarksViewController *vc = [[[KGOBookmarksViewController alloc] initWithStyle:UITableViewStylePlain] autorelease];
    vc.bookmarkedItems = array;
    vc.searchResultsDelegate = self;

    UINavigationController *navC = [[[UINavigationController alloc] initWithRootViewController:vc] autorelease];
    navC.modalPresentationStyle = UIModalPresentationFormSheet;
    navC.navigationBar.barStyle = [[KGOTheme sharedTheme] defaultNavBarStyle];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self presentModalViewController:navC animated:YES];
        
    } else {
        [self dismissPopoverAnimated:YES];
        self.selectedPopover = [[[UIPopoverController alloc] initWithContentViewController:navC] autorelease];
        // 320 and 600 are the minimum width and maximum height specified in the documentation
        self.selectedPopover.popoverContentSize = CGSizeMake(320, 600);
        self.selectedPopover.delegate = self;
        [self.selectedPopover presentPopoverFromBarButtonItem:_bookmarksBarButtonItem
                                     permittedArrowDirections:UIPopoverArrowDirectionUp
                                                     animated:YES];
    }
}

- (IBAction)settingsButtonPressed {
	MapSettingsViewController *vc = [[[MapSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
    vc.title = NSLocalizedString(@"MAP_SETTINGS_TITLE", @"Map Settings");
    vc.view.backgroundColor = [[KGOTheme sharedTheme] backgroundColorForApplication];
    
    UINavigationController *navC = [[[UINavigationController alloc] initWithRootViewController:vc] autorelease];
    navC.modalPresentationStyle = UIModalPresentationFormSheet;
    navC.navigationBar.barStyle = [[KGOTheme sharedTheme] defaultNavBarStyle];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UIBarButtonItem *item = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                               target:self
                                                                               action:@selector(dismissModalViewControllerAnimated:)] autorelease];
        vc.navigationItem.rightBarButtonItem = item;
        [self presentModalViewController:navC animated:YES];
        
    } else {
        [self dismissPopoverAnimated:YES];
        self.selectedPopover = [[[UIPopoverController alloc] initWithContentViewController:navC] autorelease];
        self.selectedPopover.popoverContentSize = CGSizeMake(320, 240);
        self.selectedPopover.delegate = self;
        [self.selectedPopover presentPopoverFromBarButtonItem:_settingsBarButtonItem
                                     permittedArrowDirections:UIPopoverArrowDirectionUp
                                                     animated:YES];
    }
}

- (IBAction)locateUserButtonPressed
{
    _didCenter = NO;
    
    if (!_userLocation) {
        if (!_locationManager) {
            _locationManager = [[CLLocationManager alloc] init];
            _locationManager.distanceFilter = kCLDistanceFilterNone;
            _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
            _locationManager.delegate = self;
       
        }
        _userLocation = [[_locationManager location] retain];
    }
    
    if (_userLocation) {
        [self showUserLocationIfInRange];
        
    } else {
        [_locationManager startUpdatingLocation];
    }
}


- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.selectedPopover = nil;
}

- (void)dismissPopoverAnimated:(BOOL)animated;
{
    if (self.selectedPopover) {
        [self.selectedPopover dismissPopoverAnimated:YES];
        self.selectedPopover = nil;
    }
}

#pragma mark User location

- (void)showUserLocationIfInRange
{
    if (_didCenter) {
        return;
    }
    
    // TODO: remove this thing about NSUserDefaults if we aren't actually
    // going to use it
    CLLocation *location = nil;
    NSDictionary *locationPreferences = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"Location"];
    if (!locationPreferences) {    
        KGOAppDelegate *appDelegate = KGO_SHARED_APP_DELEGATE();
        locationPreferences = [[appDelegate appConfig] dictionaryForKey:@"Location"];
    }
    
    NSString *latLonString = [locationPreferences nonemptyStringForKey:@"DefaultCenter"];
    if (latLonString) {
        NSArray *parts = [latLonString componentsSeparatedByString:@","];
        if (parts.count == 2) {
            NSString *lat = [parts objectAtIndex:0];
            NSString *lon = [parts objectAtIndex:1];
            location = [[[CLLocation alloc] initWithLatitude:[lat floatValue] longitude:[lon floatValue]] autorelease];
        }
    }
    
    DLog(@"%@ %@", location, _userLocation);
    // TODO: make maximum distance a config parameter
    if ([_userLocation distanceFromLocation:location] <= 40000) {
        if (!self.mapView.showsUserLocation) {
            self.mapView.showsUserLocation = YES;
        } else {
            if (!_didCenter) {
                self.mapView.centerCoordinate = _userLocation.coordinate;
                _didCenter = YES;
            }
        }
        
    } else {
        DLog(@"distance %.1f is out of bounds", [_userLocation distanceFromLocation:location]);
        
        NSString *message = NSLocalizedString(@"MAP_TOO_FAR_ALERT_MESSAGE", @"Cannot show your location because you are too far away");
        UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:nil
                                                             message:message
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil] autorelease];
        [alertView show];
        
        self.mapView.showsUserLocation = NO;
        _locateUserButton.enabled = NO;
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) {
        _locateUserButton.enabled = NO;
        [_locationManager release];
        _locationManager = nil;

        self.mapView.showsUserLocation = NO;
    } else {
        _locateUserButton.enabled = YES;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    DLog(@"location update failed: %@", [error description]);
    if ([error code] == kCLErrorDenied) {
        [_locationManager stopUpdatingLocation];
        [_locationManager release];
        _locationManager = nil;

        _locateUserButton.enabled = NO;
        self.mapView.showsUserLocation = NO;
    }    
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    [_userLocation release];
    _userLocation = [newLocation retain];
    
    [_locationManager stopUpdatingHeading];
    [_locationManager release];
    _locationManager = nil;
    
    [self showUserLocationIfInRange];
}

#pragma mark Map/List

- (void)showMapListToggle {
    UIImage *mapButton = [UIImage imageWithPathName:@"common/button-icon-viewonmap"];
    UIImage *listButton = [UIImage imageWithPathName:@"common/button-icon-viewaslist"];
    CGFloat width = mapButton.size.width + listButton.size.width + 4 * 4.0; // 4.0 is spacing defined in KGOSearchBar.m

	if (!_mapListToggle) {
		_mapListToggle = [[KGOSegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:mapButton, listButton, nil]];
        _mapListToggle.frame = CGRectMake(0, 0, width, 31);
        _mapListToggle.tabFont = [UIFont boldSystemFontOfSize:[UIFont smallSystemFontSize]];
        _mapListToggle.selectedSegmentIndex = 0;
		[_mapListToggle addTarget:self action:@selector(mapListSelectionChanged:) forControlEvents:UIControlEventValueChanged];
	}
	
	if (!_searchBar.toolbarItems.count && ![_searchBar showsCancelButton]) {
		UIBarButtonItem *item = [[[UIBarButtonItem alloc] initWithCustomView:_mapListToggle] autorelease];
		item.width = width;
		[_searchBar addToolbarButton:item animated:NO];
	}
}

- (void)hideMapListToggle {
	if (_searchBar.toolbarItems.count) {
		[_searchBar setToolbarItems:nil animated:YES];
	}
	
	[_mapListToggle release];
	_mapListToggle = nil;
}

- (void)mapListSelectionChanged:(id)sender {
	if (sender == _mapListToggle) {
		switch (_mapListToggle.selectedSegmentIndex) {
			case 0:
				[self switchToMapView];
				break;
			case 1:
				[self switchToListView];
				break;
			default:
				break;
		}
	}
}

- (void)switchToMapView {
	[self.view bringSubviewToFront:self.mapView];
	[self.view bringSubviewToFront:_bottomBar];
	
    // TODO: fine-tune when to enable this, e.g under proximity and gps enabled conditions
    [_locateUserButton setEnabled:YES];
    
    _mapListToggle.selectedSegmentIndex = 0;
}

- (void)switchToListView {
	if (_searchResultsTableView) {
		[self.view bringSubviewToFront:_searchResultsTableView];
	}
    
    [_locateUserButton setEnabled:NO];
	
    _mapListToggle.selectedSegmentIndex = 1;
}

#pragma mark MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    if (!_didCenter) {
        self.mapView.centerCoordinate = userLocation.coordinate;
        _didCenter = YES;
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)aMapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    MKAnnotationView *view = nil;
    if ([annotation isKindOfClass:[KGOPlacemark class]]) {
        static NSString *AnnotationIdentifier = @"adfgweg";
        view = [aMapView dequeueReusableAnnotationViewWithIdentifier:AnnotationIdentifier];
        if (!view) {
            UIImage *pinImage = [UIImage imageWithPathName:@"modules/map/map_pin"];
            if (pinImage) {
                view = [[[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AnnotationIdentifier] autorelease];
                view.image = pinImage;
            } else {
                view = [[[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AnnotationIdentifier] autorelease];
            }
            view.canShowCallout = YES;
            
            KGONavigationStyle navStyle = [KGO_SHARED_APP_DELEGATE() navigationStyle];
            if (navStyle != KGONavigationStyleTabletSidebar) {
                // TODO: not all annotations will want to do this
                view.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            }
        }
    } else if ([annotation conformsToProtocol:@protocol(KGOSearchResult)]) {
        id<KGOSearchResult> aResult = (id<KGOSearchResult>)annotation;
        if ([aResult respondsToSelector:@selector(annotationImage)]) {
            UIImage *image = [aResult annotationImage];
            if (image) {
                view = [[[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"fajwioth"] autorelease];
                view.image = image;
                view.canShowCallout = YES;
                
                KGONavigationStyle navStyle = [KGO_SHARED_APP_DELEGATE() navigationStyle];
                if (navStyle != KGONavigationStyleTabletSidebar) {
                    // TODO: not all annotations will want to do this
                    view.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
                }
            }
        }
    }
    return view;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    id<MKAnnotation> annotation = view.annotation;
    if ([annotation conformsToProtocol:@protocol(KGOSearchResult)]) {
        KGOAppDelegate *appDelegate = KGO_SHARED_APP_DELEGATE();
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:annotation, @"place", self, @"pagerController", nil];
        [appDelegate showPage:LocalPathPageNameDetail forModuleTag:self.mapModule.tag params:params];
    }
}

- (void)mapView:(MKMapView *)aMapView didAddAnnotationViews:(NSArray *)views
{
    NSInteger calloutCount = 0;
    id<MKAnnotation> selectedAnnotation = nil;
    for (MKAnnotationView *aView in views) {
        if ([aView canShowCallout]) {
            calloutCount++;
            if (calloutCount > 1)
                return;
            selectedAnnotation = aView.annotation;
        }
    }
    
    if (calloutCount == 1) {
        [aMapView selectAnnotation:selectedAnnotation animated:YES];
    }
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    KGOAppDelegate *appDelegate = KGO_SHARED_APP_DELEGATE();
    KGONavigationStyle navStyle = [appDelegate navigationStyle];
    // TODO: clean up sidebar home screen so we don't have to deal with this
    if (navStyle == KGONavigationStyleTabletSidebar) {
        id<MKAnnotation> annotation = view.annotation;
        if ([annotation conformsToProtocol:@protocol(KGOSearchResult)]) {
            NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:annotation, @"place", self, @"pagerController", nil];
            UIViewController *vc = [self.mapModule modulePage:LocalPathPageNameDetail params:params];
            [(KGOSidebarFrameViewController *)[appDelegate homescreen] showDetailViewController:vc];
        }
    }
}

- (void)mapView:(MKMapView *)aMapView didDeselectAnnotationView:(MKAnnotationView *)view
{
    NSInteger searchResultAnnotationCount = aMapView.selectedAnnotations.count;
    for (id<MKAnnotation> anAnnotation in aMapView.selectedAnnotations) {
        if (view.annotation == anAnnotation // this is what was deselected
            || ![anAnnotation conformsToProtocol:@protocol(KGOSearchResult)] // we don't count annotations not provided by us
        ) {
            searchResultAnnotationCount--;
        }
    }
    
    if (!searchResultAnnotationCount) {    
        KGOAppDelegate *appDelegate = KGO_SHARED_APP_DELEGATE();
        KGONavigationStyle navStyle = [appDelegate navigationStyle];
        // TODO: clean up sidebar home screen so we don't have to deal with this
        if (navStyle == KGONavigationStyleTabletSidebar) {
            [(KGOSidebarFrameViewController *)[appDelegate homescreen] hideDetailViewController];
        }
    }
}

#pragma mark KGODetailPagerController

- (id<KGOSearchResult>)pager:(KGODetailPager *)pager contentForPageAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray *displayables = [NSMutableArray array];
    for (id<MKAnnotation> anAnnotation in self.mapView.annotations) {
        if ([anAnnotation conformsToProtocol:@protocol(KGOSearchResult)]) {
            [displayables addObject:anAnnotation];
        }
    }
    return [displayables objectAtIndex:indexPath.row];
}

- (NSInteger)pager:(KGODetailPager *)pager numberOfPagesInSection:(NSInteger)section
{
    NSInteger count = 0;
    for (id<MKAnnotation> anAnnotation in self.mapView.annotations) {
        if ([anAnnotation conformsToProtocol:@protocol(KGOSearchResult)]) {
            count++;
        }
    }
    return count;
}

#pragma mark SearchDisplayDelegate

- (BOOL)searchControllerShouldShowSuggestions:(KGOSearchDisplayController *)controller {
    return [KGO_SHARED_APP_DELEGATE() navigationStyle] != KGONavigationStyleTabletSidebar;
}

- (NSArray *)searchControllerValidModules:(KGOSearchDisplayController *)controller {
	return [NSArray arrayWithObject:self.mapModule.tag];
}

- (NSString *)searchControllerModuleTag:(KGOSearchDisplayController *)controller {
	return self.mapModule.tag;
}

- (void)resultsHolder:(id<KGOSearchResultsHolder>)resultsHolder didSelectResult:(id<KGOSearchResult>)aResult {
    if ([resultsHolder isKindOfClass:[KGOSearchDisplayController class]]) {
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:aResult, @"place", resultsHolder, @"pagerController", nil];
        KGOAppDelegate *appDelegate = KGO_SHARED_APP_DELEGATE();
        [appDelegate showPage:LocalPathPageNameDetail forModuleTag:self.mapModule.tag params:params];

    } else if ([aResult conformsToProtocol:@protocol(MKAnnotation)]) { // TODO: check if search is bookmarks, not by the result selected
        [self.mapView removeAnnotations:[self.mapView annotations]];
        id<MKAnnotation> annotation = (id<MKAnnotation>)aResult;
        [self.mapView addAnnotation:annotation];
        [self dismissPopoverAnimated:YES];
    }
}

- (BOOL)searchControllerShouldLinkToMap:(KGOSearchDisplayController *)controller {
    // override default behavior
	if (controller.showingOnlySearchResults) {
        [_searchBar setShowsCancelButton:NO animated:YES];
        [self showMapListToggle];
		[self switchToMapView]; // show our map view above the list view
	}
	return NO; // notify the controller that it's been overridden
}

- (void)searchController:(KGOSearchDisplayController *)controller didShowSearchResultsTableView:(UITableView *)tableView {
    
    if ([KGO_SHARED_APP_DELEGATE() navigationStyle] == KGONavigationStyleTabletSidebar) {
        tableView.hidden = YES;
    }

	// show our map view above the list view
	if (controller.showingOnlySearchResults) {
		[self switchToMapView];
	}
	
    [self.mapView removeAnnotations:[self.mapView annotations]];
    
    NSMutableArray *addedAnnotations = [NSMutableArray array];
	for (id<KGOSearchResult> aResult in controller.searchResults) {
		if ([aResult conformsToProtocol:@protocol(MKAnnotation)]) {
            [addedAnnotations addObject:aResult];
		}
	}
    
    [self.mapView addAnnotations:addedAnnotations];
    
    if (addedAnnotations.count) {
        // TODO: rewrite regionForAnnotations: to return a success value
        MKCoordinateRegion region = [MapHomeViewController regionForAnnotations:addedAnnotations restrictedToClass:NULL];
        if (region.center.latitude && region.center.longitude) {
            self.mapView.region = region;
        }
    }
	
	_searchResultsTableView = tableView;
}


- (void)searchController:(KGOSearchDisplayController *)controller willHideSearchResultsTableView:(UITableView *)tableView {
	for (id<KGOSearchResult> aResult in controller.searchResults) {
		if ([aResult conformsToProtocol:@protocol(MKAnnotation)]) {
			id<MKAnnotation> annotation = (id<MKAnnotation>)aResult;
			[self.mapView removeAnnotation:annotation];
		}
	}

	_searchResultsTableView = nil;
}

- (void)searchController:(KGOSearchDisplayController *)controller didBecomeActive:(BOOL)active
{
	if (!self.mapView.annotations.count && !active) {
		[self hideMapListToggle];
	}
}

// this is about 1km at the equator
#define MINIMUM_COORDINATE_DELTA 0.01

+ (MKCoordinateRegion)regionForAnnotations:(NSArray *)annotations restrictedToClass:(Class)restriction
{
    double minLat = 90;
    double maxLat = -90;
    double minLon = 180;
    double maxLon = -180;

    for (id<MKAnnotation> annotation in annotations) {
        if (!restriction || [annotation isKindOfClass:restriction]) {
            CLLocationCoordinate2D coord = annotation.coordinate;
            //Check to make sure the lat and long are in a valid range. 
            if(coord.latitude < 90 && coord.latitude > -90 && coord.longitude < 180 && coord.longitude > -180){
                if (coord.latitude > maxLat)  maxLat = coord.latitude;
                if (coord.longitude > maxLon) maxLon = coord.longitude;
                if (coord.latitude < minLat)  minLat = coord.latitude;
                if (coord.longitude < minLon) minLon = coord.longitude;
            }
        }
    }
    
    CLLocationCoordinate2D center = CLLocationCoordinate2DMake(0, 0);
    MKCoordinateSpan span = MKCoordinateSpanMake(0, 0);
    
    if (maxLat >= minLat && maxLon >= minLon) {
        center.latitude = (minLat + maxLat) / 2;
        center.longitude = (minLon + maxLon) / 2;
        
        span.latitudeDelta = fmax((maxLat - minLat) * 1.4, MINIMUM_COORDINATE_DELTA);
        span.longitudeDelta = fmax((maxLon - minLon) * 1.4, MINIMUM_COORDINATE_DELTA);
    }
    
    return MKCoordinateRegionMake(center, span);
}
/*
- (void)recenterMapForAnnotations: (NSArray *)annotations {
    //NSArray *coordinates = [self.mapView valueForKeyPath:@"annotations.coordinate" ];
    CLLocationCoordinate2D maxCoord = {-90.0f, -180.0f};
    CLLocationCoordinate2D minCoord = {90.0f, 180.0f};
    for(NSValue *value in coordinates) {
        CLLocationCoordinate2D coord = {0.0f, 0.0f};
        [value getValue:&coord];
        if(coord.longitude > maxCoord.longitude) {
            maxCoord.longitude = coord.longitude;
        }
        if(coord.latitude > maxCoord.latitude) {
            maxCoord.latitude = coord.latitude;
        }
        if(coord.longitude < minCoord.longitude) {
            minCoord.longitude = coord.longitude;
        }
        CLICK HERE to purchase this book now.MAP ANNOTATIONS 475
        if(coord.latitude < minCoord.latitude) {
            minCoord.latitude = coord.latitude;
        }
    }
    MKCoordinateRegion region = {{0.0f, 0.0f}, {0.0f, 0.0f}};
    region.center.longitude = (minCoord.longitude + maxCoord.longitude) / 2.0;
    region.center.latitude = (minCoord.latitude + maxCoord.latitude) / 2.0;
    region.span.longitudeDelta = maxCoord.longitude - minCoord.longitude;
    region.span.latitudeDelta = maxCoord.latitude - minCoord.latitude;
   
}
*/
@end
