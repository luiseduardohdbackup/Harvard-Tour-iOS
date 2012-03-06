#import "EventDetailTableView.h"
#import "CalendarModel.h"
#import "KGOContactInfo.h"
#import "UIKit+KGOAdditions.h"
#import "Foundation+KGOAdditions.h"
#import "KGORequestManager.h"
#import "KGODetailPageHeaderView.h"
#import "CalendarDataManager.h"
#import "MITMailComposeController.h"
#import "KGOAppDelegate+ModuleAdditions.h"
#import "CalendarDetailViewController.h"
#import "KGOLabel.h"
#import <EventKitUI/EKEventEditViewController.h>
#import "MapModule.h"

#define CELL_TITLE_TAG 31415
#define CELL_SUBTITLE_TAG 271
#define CELL_LABELS_HORIZONTAL_PADDING 10
#define CELL_LABELS_VERTICAL_PADDING 10
#define CELL_ACCESSORY_PADDING 27
#define CELL_GROUPED_PADDING 10

@implementation EventDetailTableView

@synthesize dataManager, viewController, headerView = _headerView, sections = _sections;

- (id)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:style];
    if (self) {
        self.delegate = self;
        self.dataSource = self;
        self.separatorColor = [[KGOTheme sharedTheme] tableSeparatorColor];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.delegate = self;
        self.dataSource = self;
        self.separatorColor = [[KGOTheme sharedTheme] tableSeparatorColor];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.delegate = self;
        self.dataSource = self;
        self.separatorColor = [[KGOTheme sharedTheme] tableSeparatorColor];
    }
    return self;
}

- (void)dealloc
{
    if (_eventDetailRequest) {
        [_eventDetailRequest cancel];
        [_eventDetailRequest release];
    }
    self.event = nil;
    self.delegate = nil;
    self.dataSource = nil;
    self.headerView = nil;
    [super dealloc];
}

// TODO make sure the cells contents properly resize if this table view
// is resized

#pragma mark - Event

- (KGOEventWrapper *)event
{
    return _event;
}

- (void)setEvent:(KGOEventWrapper *)event
{
    [_event release];
    _event = [event retain];
    
    DLog(@"%@ %@ %@ %@", [_event description], _event.title, _event.location, _event.userInfo);
    
    [_sections release];
    _sections = nil;
    
    if (_event) {
        [self reloadData];
        self.tableHeaderView = [self viewForTableHeader];
        
        [self eventDetailsDidChange];

        // TODO: see if there is a way to tell we don't need to update this event
        if (!_event.summary.length) {
            [self requestEventDetails];
        }
    }
}

- (void)eventDetailsDidChange
{
    NSMutableArray *mutableSections = [NSMutableArray array];
    NSArray *basicInfo = [self sectionForBasicInfo];
    if (basicInfo.count) {
        [mutableSections addObject:basicInfo];
    }
    
    NSArray *attendeeInfo = [self sectionForAttendeeInfo];
    if (attendeeInfo.count) {
        [mutableSections addObject:attendeeInfo];
    }
    
    NSArray *contactInfo = [self sectionForContactInfo];
    if (contactInfo.count) {
        [mutableSections addObject:contactInfo];
    }
    
    NSArray *extendedInfo = [self sectionForExtendedInfo];
    if (extendedInfo.count) {
        [mutableSections addObject:extendedInfo];
    }
    NSArray *sections = [self sectionsForFields];
    if (sections.count) {
        [mutableSections addObjectsFromArray: sections];
    }
    
    [_sections release];
    _sections = [mutableSections copy];
    
    [self reloadData];
    
    self.tableHeaderView = [self viewForTableHeader];
}


- (NSArray *)sectionForBasicInfo
{
    NSArray *basicInfo = nil;
    if (_event.location || _event.coordinate.latitude || _event.coordinate.longitude) {
        NSMutableDictionary *locationDict = [NSMutableDictionary dictionary];
        
        if (_event.briefLocation) {
            [locationDict setObject:_event.briefLocation forKey:@"title"];
            if (_event.location) {
                [locationDict setObject:_event.location forKey:@"subtitle"];
            }
            
        } else if (_event.location) {
            [locationDict setObject:_event.location forKey:@"title"];
        } else { // if we got this far there has to be a lat/lon
            [locationDict setObject:@"View on Map" forKey:@"title"];
        }

        if (_event.coordinate.latitude || _event.coordinate.longitude) {
            [locationDict setObject:KGOAccessoryTypeMap forKey: @"accessory"];
        }
        
        basicInfo = [NSArray arrayWithObject:locationDict];
    }
    DLog(@"%@", basicInfo);
    return basicInfo;
}

- (NSArray *)sectionForAttendeeInfo
{
    NSArray *attendeeInfo = nil;
    if (_event.attendees.count) {
        NSString *attendeeString = [NSString stringWithFormat:
                                    NSLocalizedString(@"CALENDAR_%d_OTHERS_ATTENDING", @"%d others attending"),
                                    _event.attendees.count];
        attendeeInfo = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 attendeeString, @"title",
                                                 KGOAccessoryTypeChevron, @"accessory",
                                                 nil]];
    }
    return attendeeInfo;
}

- (NSArray *)sectionForContactInfo
{
    NSMutableArray *contactInfo = [NSMutableArray array];
    if (_event.organizers) {
        for (KGOAttendeeWrapper *organizer in _event.organizers) {
            for (KGOEventContactInfo *aContact in organizer.contactInfo) {
                NSString *type;
                NSString *accessory;
                NSString *url = nil;
                
                if ([aContact.type isEqualToString:@"phone"]) {
                    type = NSLocalizedString(@"CALENDAR_ORGANIZER_PHONE", @"Organizer phone");
                    accessory = KGOAccessoryTypePhone;
                    url = [NSString stringWithFormat:@"tel:%@", aContact.value];
                    
                } else if ([aContact.type isEqualToString:@"email"]) {
                    type = NSLocalizedString(@"CALENDAR_ORGANIZER_EMAIL", @"Organizer email");
                    accessory = KGOAccessoryTypeEmail;
                    
                } else if ([aContact.type isEqualToString:@"url"]) {
                    type = NSLocalizedString(@"CALENDAR_EVENT_WEBSITE", @"Event website");
                    accessory = KGOAccessoryTypeExternal;
                    url = aContact.value;
                    
                } else {
                    type = NSLocalizedString(@"CALENDAR_CONTACT_INFO", @"Contact");
                    accessory = KGOAccessoryTypeNone;
                }
                
                NSDictionary *cellInfo = nil;
                if (url) {
                    cellInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                type, @"title", aContact.value, @"subtitle", accessory, @"accessory", url, @"url", nil];
                } else {
                    cellInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                type, @"title", aContact.value, @"subtitle", accessory, @"accessory", nil];
                }
                
                
                [contactInfo addObject:cellInfo];
            }
        }
        
    }
    return contactInfo;
}

#define DESCRIPTION_WEBVIEW_TAG 5

- (NSInteger)numberOfOccurString:(NSString *)match inString:(NSString *)src {
    return [[src componentsSeparatedByString:match] count] - 1; 
}

- (NSArray *)sectionForExtendedInfo
{
    NSArray *extendedInfo = nil;
    
    if (_event.summary) {
        _event.summary = [_event.summary stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
        CGFloat offset = [self numberOfOccurString:@"<br>" inString:_event.summary] * 10;
        //just use the label to calculate the height of the webview.
        KGOLabel *label = [KGOLabel multilineLabelWithText:_event.summary
                                                      font:[[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyBodyText]
                                                     width:self.frame.size.width - 40];
        CGRect frame = label.frame;
        frame = CGRectMake(10, 10, 310, frame.size.height + offset);
        UIWebView *webView = [[UIWebView alloc] initWithFrame:frame];
        webView.tag = DESCRIPTION_WEBVIEW_TAG;
        KGOHTMLTemplate *template = [KGOHTMLTemplate templateWithPathName:@"modules/calendar/events_template.html"];
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        [values setValue:(_event.summary ? _event.summary : @"") forKey:@"BODY"];
        [webView loadTemplate:template values:values];
        extendedInfo = [NSArray arrayWithObject:webView];
        [webView release];
    }
    return extendedInfo;
}

- (NSArray *)sectionsForFields
{
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *currentSection = nil;
    NSString *currentSectionName = @"";
    
    if (_event.fields) {
        for (NSDictionary *field in _event.fields) {
            NSString *label = [field nonemptyStringForKey:@"title"];
            NSString *value = [field nonemptyStringForKey:@"value"];
            NSString *type = [field nonemptyStringForKey:@"type"];
            
            NSString *accessory = nil;
            NSString *url = nil;
            if ([type isEqualToString:@"phone"]) {
                if (!label) {
                    label = NSLocalizedString(@"CALENDAR_ORGANIZER_PHONE", @"Organizer phone");
                }
                accessory = KGOAccessoryTypePhone;
                url = [NSString stringWithFormat:@"tel:%@", value];
                
            } else if ([type isEqualToString:@"email"]) {
                if (!label) {
                    label = NSLocalizedString(@"CALENDAR_ORGANIZER_EMAIL", @"Organizer email");
                }
                accessory = KGOAccessoryTypeEmail;
                
            } else if ([type isEqualToString:@"url"]) {
                accessory = KGOAccessoryTypeExternal;
                url = [field nonemptyStringForKey:@"value"];
            }
            
            NSDictionary *cellInfo = nil;
            if (label) {
                cellInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            label, @"title", value, @"subtitle", accessory, @"accessory", url, @"url", nil];
            } else {
                cellInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            value, @"title", accessory, @"accessory", url, @"url", nil];
            }
            
            NSString *sectionName = [field stringForKey:@"section"];
            if (![sectionName isEqualToString:currentSectionName]) {
                if ([currentSection count]) {
                    // new section, store previous section and start over
                    [sections addObject:currentSection];
                    currentSection = nil;
                }
                currentSectionName = sectionName;
            }
            if (!currentSection) {
                currentSection = [NSMutableArray array];
            }
            
            [currentSection addObject:cellInfo];
        }
        
        // Add last section if there is anything in it
        if ([currentSection count]) {
            [sections addObject:currentSection];
        }
    }
    return sections;
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    DLog(@"%d %@", section, [_sections objectAtIndex:section]);
    
    return [[_sections objectAtIndex:section] count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _sections.count;
}

- (CGFloat)cellLabelWidthWithAccessory:(BOOL)hasAccessory {
    CGFloat cellWidth = self.frame.size.width;
    cellWidth = cellWidth - 2 * CELL_LABELS_HORIZONTAL_PADDING;
    if (hasAccessory) {
        cellWidth = cellWidth - CELL_ACCESSORY_PADDING;
    }
    
    if (self.style == UITableViewStyleGrouped) {
        cellWidth = cellWidth - 2 * CELL_GROUPED_PADDING;
    }
    return cellWidth;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCellStyle style = UITableViewCellStyleDefault;
    NSString *cellIdentifier;
    DLog(@"%@ %@", indexPath, [_sections objectAtIndex:indexPath.section]);
    id cellData = [[_sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    if ([cellData isKindOfClass:[NSDictionary class]]) {
        if ([cellData objectForKey:@"subtitle"]) {
            style = UITableViewCellStyleSubtitle;
        }
        cellIdentifier = [NSString stringWithFormat:@"%d", style];

    } else {
        cellIdentifier = [NSString stringWithFormat:@"%d.%d", indexPath.section, indexPath.row];
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:style reuseIdentifier:cellIdentifier] autorelease];
        
        UILabel *titleLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
        titleLabel.tag = CELL_TITLE_TAG;
        titleLabel.font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyNavListTitle];
        titleLabel.textColor = [[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertyNavListTitle];
        titleLabel.numberOfLines = 0;
        titleLabel.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:titleLabel];
        
        UILabel *subtitleLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
        subtitleLabel.tag = CELL_SUBTITLE_TAG;
        subtitleLabel.font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyNavListSubtitle];
        subtitleLabel.textColor = [[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertyNavListSubtitle];
        subtitleLabel.numberOfLines = 0;
        subtitleLabel.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:subtitleLabel];

    } else {
        cell.imageView.image = nil;
        UIView *view = [cell viewWithTag:DESCRIPTION_WEBVIEW_TAG];
        [view removeFromSuperview];
    }
        
    if ([cellData isKindOfClass:[NSDictionary class]]) {  
        UILabel *titleLabel = (UILabel *)[cell viewWithTag:CELL_TITLE_TAG];
        UILabel *subtitleLabel = (UILabel *)[cell viewWithTag:CELL_SUBTITLE_TAG];
        titleLabel.text = [cellData objectForKey:@"title"];
        subtitleLabel.text = [cellData objectForKey:@"subtitle"];
        if ([cellData objectForKey:@"image"]) {
            cell.imageView.image = [cellData objectForKey:@"image"];
        }
        
        NSString *accessory = [cellData objectForKey:@"accessory"];
        cell.accessoryView = [[KGOTheme sharedTheme] accessoryViewForType:accessory];
        BOOL hasAccessory = accessory && ![accessory isEqualToString:KGOAccessoryTypeNone];
        if (hasAccessory) {
            [cell applyBackgroundThemeColorForIndexPath:indexPath tableView:tableView];
        } else {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }

        // size title and subtitle views.
        CGFloat contentViewWidth = [self cellLabelWidthWithAccessory:hasAccessory];
        CGSize titleSize = [titleLabel.text sizeWithFont:titleLabel.font constrainedToSize:CGSizeMake(contentViewWidth, 1000)];
        CGSize subtitleSize = [subtitleLabel.text sizeWithFont:subtitleLabel.font constrainedToSize:CGSizeMake(contentViewWidth, 1000)];
        titleLabel.frame = CGRectMake(CELL_LABELS_HORIZONTAL_PADDING, CELL_LABELS_VERTICAL_PADDING, 
                                      contentViewWidth, titleSize.height);
        subtitleLabel.frame = CGRectMake(CELL_LABELS_HORIZONTAL_PADDING, titleSize.height + CELL_LABELS_VERTICAL_PADDING, 
                                         contentViewWidth, subtitleSize.height);
        
    } else {
        if ([cellData isKindOfClass:[UIWebView class]]) {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            [cell.contentView addSubview:cellData];
        }
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id cellData = [[_sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    if ([cellData isKindOfClass:[UIWebView class]]) {
        return [(UILabel *)cellData frame].size.height + 20;
    }
    
    // calculate height
    NSString *accessory = [cellData objectForKey:@"accessory"];
    BOOL hasAccessory = accessory && ![accessory isEqualToString:KGOAccessoryTypeNone];
    
    CGFloat contentViewWidth = [self cellLabelWidthWithAccessory:hasAccessory];
    UIFont *titleFont = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyNavListTitle];
    NSString *title = [cellData objectForKey:@"title"];
    CGSize titleSize = [title sizeWithFont:titleFont constrainedToSize:CGSizeMake(contentViewWidth, 1000)];
    
    UIFont *subtitleFont = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyNavListSubtitle];
    NSString *subtitle = [cellData objectForKey:@"subtitle"];
    CGSize subtitleSize = [subtitle sizeWithFont:subtitleFont constrainedToSize:CGSizeMake(contentViewWidth, 1000)];
    
    return titleSize.height + subtitleSize.height + 2 * CELL_LABELS_VERTICAL_PADDING;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id cellData = [[_sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    if ([cellData isKindOfClass:[NSDictionary class]]) {
        NSString *accessory = [cellData objectForKey:@"accessory"];
        NSURL *url = nil;
        NSString *urlString = [cellData objectForKey:@"url"];
        if (urlString) {
            url = [NSURL URLWithString:urlString];
        }
        
        if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url];
            [tableView deselectRowAtIndexPath:indexPath animated:YES];

        } else if ([accessory isEqualToString:KGOAccessoryTypeEmail]) {
            [self.viewController presentMailControllerWithEmail:[cellData objectForKey:@"subtitle"]
                                                        subject:nil
                                                           body:nil
                                                       delegate:self];
            
        } else if ([accessory isEqualToString:KGOAccessoryTypeMap]) {
            NSArray *annotations = [NSArray arrayWithObject:_event];
            NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:annotations, @"annotations", nil];
            // TODO: redo this when we have cross-module linking
            for (KGOModule *aModule in [KGO_SHARED_APP_DELEGATE() modules]) {
                if ([aModule isKindOfClass:[MapModule class]]) {
                    [KGO_SHARED_APP_DELEGATE() showPage:LocalPathPageNameHome forModuleTag:aModule.tag params:params];
                    return;
                }
            }
        }
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error 
{
    [self.viewController dismissModalViewControllerAnimated:YES];
}

#pragma mark - Table header

- (void)headerViewFrameDidChange:(KGODetailPageHeaderView *)headerView
{
    if (self.headerView.frame.size.height != self.tableHeaderView.frame.size.height) {
        self.tableHeaderView.frame = self.headerView.frame;
    }
    self.tableHeaderView = self.headerView;
}

- (UIView *)viewForTableHeader
{
    if (!self.headerView) {
        self.headerView = [[[KGODetailPageHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 1)] autorelease];
        self.headerView.delegate = self;
        self.headerView.showsBookmarkButton = NO;
        self.headerView.showsShareButton = YES;
        
        UIImage *buttonImage = [UIImage imageWithPathName:@"modules/calendar/calendar"];
        UIImage *pressedImage = [UIImage imageWithPathName:@"modules/calendar/calendar_pressed"];
        UIButton *calendarButton = [UIButton buttonWithType:UIButtonTypeCustom];
        calendarButton.frame = CGRectMake(0, 0, buttonImage.size.width, buttonImage.size.height);
        [calendarButton setImage:buttonImage forState:UIControlStateNormal];
        [calendarButton setImage:pressedImage forState:UIControlStateHighlighted];
        [calendarButton addTarget:self
                           action:@selector(calendarButtonPressed:)
                 forControlEvents:UIControlEventTouchUpInside];
        
        [self.headerView addButton:calendarButton];
    }

    self.headerView.detailItem = self.event;
    
    // time
    NSString *dateString = [self.dataManager mediumDateStringFromDate:_event.startDate];
    NSString *timeString = nil;
    if (_event.allDay) {
        NSString *endDateString = [self.dataManager mediumDateStringFromDate:_event.endDate];
        if ([endDateString isEqualToString:dateString]) {
            timeString = [NSString stringWithFormat:@"%@\n%@", dateString, NSLocalizedString(@"CALENDAR_ALL_DAY_SUBTITLE", @"All day")];
        } else {
            timeString = [NSString stringWithFormat:@"%@ - %@", dateString, endDateString];

        }
    } else {
        if (_event.endDate) {
            timeString = [NSString stringWithFormat:@"%@\n%@-%@",
                          dateString,
                          [self.dataManager shortTimeStringFromDate:_event.startDate],
                          [self.dataManager shortTimeStringFromDate:_event.endDate]];
        } else {
            timeString = [NSString stringWithFormat:@"%@\n%@",
                          dateString,
                          [self.dataManager shortTimeStringFromDate:_event.startDate]];
        }
    }
    self.headerView.subtitleLabel.text = timeString;
    
    return self.headerView;
}

- (void)headerView:(KGODetailPageHeaderView *)headerView shareButtonPressed:(id)sender
{
    if ([self.viewController isKindOfClass:[CalendarDetailViewController class]]) {
        [(CalendarDetailViewController *)self.viewController shareButtonPressed:sender];
    }
}

//# pragma mark CalendarButtonDelegate

- (void)calendarButtonPressed:(id)sender {
    
    EKEventStore *eventStore = [[[EKEventStore alloc] init] autorelease];
    
    EKEvent *newEvent = [EKEvent eventWithEventStore:eventStore];
    newEvent.calendar = [eventStore defaultCalendarForNewEvents];
    
    newEvent.title = self.event.title;
    newEvent.startDate = self.event.startDate;
    newEvent.endDate = self.event.endDate;
    
    if (self.event.location.length > 0)
        newEvent.location = self.event.location;
    
    if (self.event.summary) {
        newEvent.notes = self.event.summary;
    }

    
    EKEventEditViewController *eventViewController = [[[EKEventEditViewController alloc] init] autorelease];
    eventViewController.event = newEvent;
    eventViewController.eventStore = eventStore;
    if ([self.viewController isKindOfClass:[CalendarDetailViewController class]]) {
        eventViewController.editViewDelegate = (CalendarDetailViewController *)self.viewController;
    }
    [self.viewController presentModalViewController:eventViewController animated:YES];    
}

#pragma mark detail

- (void)requestEventDetails
{
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            _event.identifier, @"id",
                            [NSString stringWithFormat:@"%.0f", [_event.startDate timeIntervalSince1970]], @"start",
                            nil];
    DLog(@"requesting event details %@", params);
    if (_eventDetailRequest) {
        [_eventDetailRequest cancel];
        [_eventDetailRequest release];
        _eventDetailRequest = nil;
    }
    
    _eventDetailRequest = [[[KGORequestManager sharedManager] requestWithDelegate:self
                                                                           module:self.dataManager.moduleTag
                                                                             path:@"detail"
                                                                          version:1
                                                                           params:params] retain];
    [_eventDetailRequest connect];
}

- (void)request:(KGORequest *)request didFailWithError:(NSError *)error
{
    DLog(@"request failed: %@", [error description]);
}

- (void)request:(KGORequest *)request didReceiveResult:(id)result
{
    [_event updateWithDictionary:result];
    [_event saveToCoreData];

    [self eventDetailsDidChange];
}

- (void)requestWillTerminate:(KGORequest *)request
{
    [_eventDetailRequest release];
    _eventDetailRequest = nil;
}

@end
