#import "PeopleDetailsViewController.h"
#import "KGOAppDelegate+ModuleAdditions.h"
#import "UIKit+KGOAdditions.h"
#import "Foundation+KGOAdditions.h"
#import "HarvardNavigationController.h"
#import "AnalyticsWrapper.h"
#import "MITMailComposeController.h"
#import "KGOTheme.h"
#import "CoreDataManager.h"
#import "KGOLabel.h"

@interface PeopleDetailsViewController (Private)

- (NSString *)displayTitleForSection:(NSInteger)section label:(NSString *)label;
- (void)displayPerson;

@end


@implementation PeopleDetailsViewController

@synthesize sectionArray = _sectionArray, person = _person, pager;

- (void)viewDidLoad
{
    // TODO: provide interface to mark person as viewed
    //self.person.viewed = [NSNumber numberWithBool:YES];
    [[CoreDataManager sharedManager] saveData];
    
	self.title = NSLocalizedString(@"PEOPLE_DETAIL_VIEW_TITLE", @"Info");
    
    [self displayPerson];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)dealloc {
	
	self.sectionArray = nil;
    self.person = nil;
    [super dealloc];
}

- (void)displayPerson {
    [self.person markAsRecentlyViewed];

    _addressSection = NSNotFound;
    _phoneSection = NSNotFound;
    _emailSection = NSNotFound;
    
    // information in header: photo, name
    
    UIFont *font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyContentTitle];
    KGOLabel *nameLabel = [KGOLabel multilineLabelWithText:self.person.name font:font width:self.tableView.frame.size.width - 20];
    nameLabel.textColor = [[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertyContentTitle];
    nameLabel.frame = CGRectMake(10, 10, nameLabel.frame.size.width, nameLabel.frame.size.height);

    UIView *header = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, nameLabel.frame.size.height + 14)] autorelease];
	[header addSubview:nameLabel];

	self.tableView.tableHeaderView = header;

    // sections
    
	self.sectionArray = [NSMutableArray array];
    
    NSMutableArray *currentSection = nil;

    // - organization/department/title TODO: make more flexible we can do stuff like split title/org at harvard
    for (NSDictionary *aDict in self.person.organizations) {
        currentSection = [NSMutableArray array];
        NSDictionary *orgDict = [aDict dictionaryForKey:@"value"];
        if (orgDict) {
            for (NSString *label in [NSArray arrayWithObjects:@"jobTitle", @"organization", @"department", nil]) {
                NSString *value = [orgDict nonemptyStringForKey:label];
                if (value) {
                    [currentSection addObject:[NSDictionary dictionaryWithObjectsAndKeys:label, @"label", value, @"value", nil]];
                }
            }
            [self.sectionArray addObject:currentSection];
        }
    }
    
    // - emails
    if (self.person.emails.count) {
        _emailSection = self.sectionArray.count;

        currentSection = [NSMutableArray array];
        for (NSDictionary *aDict in self.person.emails) {
            [currentSection addObject:aDict];
        }
        [self.sectionArray addObject:currentSection];
    }
    
    // - phones
    if (self.person.phones.count) {
        _phoneSection = self.sectionArray.count;
        
        currentSection = [NSMutableArray array];
        for (NSDictionary *aDict in self.person.phones) {
            [currentSection addObject:aDict];
        }
        [self.sectionArray addObject:currentSection];
    }
    
    // - addresses
    if (self.person.addresses.count) {
        _addressSection = self.sectionArray.count;
        
        currentSection = [NSMutableArray array];
        for (NSDictionary *aDict in self.person.addresses) {
            NSString *label = [aDict stringForKey:@"label"];
            if (!label) {
                label = [aDict stringForKey:@"title"];
            }
            if (!label) {
                label = [NSString string];
            }
            
            NSString *displayAddress = [NSString string];
            NSDictionary *valueDict = [aDict objectForKey:@"value"];
            if (valueDict) {
                displayAddress = [KGOPersonWrapper displayAddressForDict:valueDict];
            }
            
            [currentSection addObject:[NSDictionary dictionaryWithObjectsAndKeys:displayAddress, @"value", label, @"label", nil]];
        }
        [self.sectionArray addObject:currentSection];
    }
    
    // - IM
    if (self.person.screennames.count) {
        currentSection = [NSMutableArray array];
        for (NSDictionary *aDict in self.person.screennames) {
            [currentSection addObject:aDict];
        }
        [self.sectionArray addObject:currentSection];
    }
    
    // - urls
    if (self.person.webpages.count) {
        currentSection = [NSMutableArray array];
        for (NSDictionary *aDict in self.person.webpages) {
            [currentSection addObject:aDict];
        }
        [self.sectionArray addObject:currentSection];
    }
    
    [self.tableView reloadData];
}

#pragma mark KGODetailPager

- (void)pager:(KGODetailPager*)pager showContentForPage:(id<KGOSearchResult>)content {
    if ([content isKindOfClass:[KGOPersonWrapper class]]) {
        self.person = (KGOPersonWrapper *)content;
        [self displayPerson];
    }
}

#pragma mark -
#pragma mark Table view methods

- (NSString *)displayTitleForSection:(NSInteger)section label:(NSString *)label {
    static NSDictionary *displayLabels = nil;
    if (displayLabels == nil) {    
        displayLabels = [[NSDictionary alloc] initWithObjectsAndKeys:
                         NSLocalizedString(@"PEOPLE_CONTACT_LABEL_HOME", @"Home"), @"home",
                         NSLocalizedString(@"PEOPLE_CONTACT_LABEL_WORK", @"Work"), @"work",
                         NSLocalizedString(@"PEOPLE_CONTACT_LABEL_OTHER", @"Other"), @"other",
                         nil];
    }
    NSString *title = [displayLabels objectForKey:label];
    if (title)
        return title;
    return label;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	
	return [self.sectionArray count] + 1;
	
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == [self.sectionArray count])
		return 2;
	return [[self.sectionArray objectAtIndex:section] count];
}

- (KGOTableCellStyle)tableView:(UITableView *)tableView styleForCellAtIndexPath:(NSIndexPath *)indexPath {
	return (indexPath.section < [self.sectionArray count]) ? KGOTableCellStyleValue2 : KGOTableCellStyleDefault;
}

- (CellManipulator)tableView:(UITableView *)tableView manipulatorForCellAtIndexPath:(NSIndexPath *)indexPath {
    NSString *title;
    NSString *accessoryTag = nil;
    BOOL centerText = NO;
    
    if (indexPath.section == [self.sectionArray count]) {
        
        centerText = YES;
        if (indexPath.row == 0) {
            title = NSLocalizedString(@"PEOPLE_CREATE_NEW_CONTACT", @"Create New Contact");
        } else {
            title = NSLocalizedString(@"PEOPLE_ADD_TO_EXISTING_CONTACT", @"Add to Existing Contact");
        }

    } else {
		NSDictionary *personAttribute = [[self.sectionArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        NSString *label = [personAttribute objectForKey:@"label"];
        if (!label) {
            label = [personAttribute stringForKey:@"title"];
        }
        title = [self displayTitleForSection:indexPath.section label:label];

        if (indexPath.section == _addressSection) {
            accessoryTag = KGOAccessoryTypeMap;
            // TODO: check for lookup-ability of address
            //accessoryTag = KGOAccessoryTypeBlank;
        } else if (indexPath.section == _emailSection) {
            accessoryTag = KGOAccessoryTypeEmail;
        } else if (indexPath.section == _phoneSection) {
            accessoryTag = KGOAccessoryTypePhone;
        }
    }
    
    return [[^(UITableViewCell *cell) {
        cell.textLabel.text = title;
        cell.accessoryView = [[KGOTheme sharedTheme] accessoryViewForType:accessoryTag];
        if (centerText) cell.textLabel.textAlignment = UITextAlignmentCenter;
    } copy] autorelease];
}

- (NSArray *)tableView:(UITableView *)tableView viewsForCellAtIndexPath:(NSIndexPath *)indexPath {
    
	if (indexPath.section < [self.sectionArray count]) { 

		NSDictionary *personAttribute = [[self.sectionArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        NSString *value = [personAttribute stringForKey:@"value"];
        if (!value) {
            value = @"";
        }

        UIFont *font = [[KGOTheme sharedTheme] fontForThemedProperty:KGOThemePropertyNavListValue];
        
        // inner 20 for padding; 0.75 is approx ratio allocated to detail text label, 33 for accessory
        CGFloat width = floor((tableView.frame.size.width - 20) * 0.75) - 20;
        CGFloat originX = self.tableView.frame.size.width - 33 - width;
        
        UIColor *textColor = [[KGOTheme sharedTheme] textColorForThemedProperty:KGOThemePropertyNavListValue];

        // use a textView for the address so people can copy/paste.
        if (indexPath.section == _addressSection) {

            CGSize size = [value sizeWithFont:font
                            constrainedToSize:CGSizeMake(width, 1989.0f) // 2009 minus vertical padding
                                lineBreakMode:UILineBreakModeWordWrap];
            
            CGRect frame = CGRectMake(originX, 10, width, size.height);
            
            UITextView *textView = [[[UITextView alloc] initWithFrame:frame] autorelease];
            textView.text = value;
            textView.backgroundColor = [UIColor clearColor];
            textView.font = font;
            textView.textColor = textColor;
            textView.editable = NO;
            textView.scrollEnabled = NO;
            textView.contentInset = UIEdgeInsetsMake(-8, -9, -8, -9);
            
            //textView.userInteractionEnabled = addressSearchAnnotation == nil;
            
            return [NSArray arrayWithObject:textView];

        } else {
            UILineBreakMode breakMode = UILineBreakModeWordWrap;
            if (indexPath.section == _emailSection) {
                breakMode = UILineBreakModeCharacterWrap;
            }
            KGOLabel *label = [KGOLabel multilineLabelWithText:value
                                                          font:font
                                                         width:width
                                                 lineBreakMode:breakMode];
            label.frame = CGRectMake(originX, 10, width, label.frame.size.height);
            return [NSArray arrayWithObject:label];
        }
    }
    
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == [self.sectionArray count]) { // user selected create/add to contacts
		
		if (indexPath.row == 0) { // create addressbook entry
			ABNewPersonViewController *creator = [[[ABNewPersonViewController alloc] init] autorelease];
			creator.displayedPerson = [self.person convertToABPerson];
			[creator setNewPersonViewDelegate:self];
            
            UINavigationController *addContactNavController = [[UINavigationController alloc] initWithRootViewController:creator];
            addContactNavController.navigationBar.barStyle = [[KGOTheme sharedTheme] defaultNavBarStyle];
            [self presentModalViewController:addContactNavController animated:YES];
            [addContactNavController release];
            
			
		} else {
			ABPeoplePickerNavigationController *picker = [[[ABPeoplePickerNavigationController alloc] init] autorelease];
			[picker setPeoplePickerDelegate:self];
            
            [self presentModalViewController:picker animated:YES];
		}
		
	} else {
		// React if the cell tapped has text that that matches the display name of mail, telephonenumber, or postaladdress.
		if (indexPath.section == _emailSection) {
            NSDictionary *personAttribute = [[self.sectionArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
            [self emailIconTapped:[personAttribute nonemptyStringForKey:@"value"]];
        }
		else if (indexPath.section == _phoneSection) {
            NSDictionary *personAttribute = [[self.sectionArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
            [self phoneIconTapped:[personAttribute nonemptyStringForKey:@"value"]];
        }
		else if (indexPath.section == _addressSection) {
            NSDictionary *personAttribute = [[self.sectionArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
            [self mapIconTapped:[personAttribute nonemptyStringForKey:@"value"]];
        }
	}
	
	[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark -
#pragma mark Address book methods

- (void)newPersonViewController:(ABNewPersonViewController *)newPersonViewController didCompleteWithNewPerson:(ABRecordRef)person
{
    [self dismissModalViewControllerAnimated:YES];
}

- (BOOL)        personViewController:(ABPersonViewController *)personViewController 
 shouldPerformDefaultActionForPerson:(ABRecordRef)person 
							property:(ABPropertyID)property 
						  identifier:(ABMultiValueIdentifier)identifierForValue
{
    // causes the app to place a phone call, send email, etc.
    // if we want to perform custom actions, return NO and add
    // approriate address book actions
	return YES;
}

/* when they pick a person we are recreating the entire record using
 * the union of what was previously there and what we received from
 * the server
 */
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker 
	  shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
    self.person.ABPerson = person;
    [self.person saveToAddressBook];
    
    [self dismissModalViewControllerAnimated:YES];
	
	return NO; // don't navigate to built-in view
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker 
	  shouldContinueAfterSelectingPerson:(ABRecordRef)person 
								property:(ABPropertyID)property 
							  identifier:(ABMultiValueIdentifier)identifier
{
	return NO;
}
	
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
    [self dismissModalViewControllerAnimated:YES];
}


#pragma mark -
#pragma mark App-switching actions

- (void)mapIconTapped:(NSString *)address
{
    // TODO
}

- (void)phoneIconTapped:(NSString *)phone
{
    NSURL *externURL = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", phone]];
    if ([[UIApplication sharedApplication] canOpenURL:externURL]) {
        [[UIApplication sharedApplication] openURL:externURL];
    }
}

- (void)emailIconTapped:(NSString *)email
{
    [self presentMailControllerWithEmail:email subject:nil body:nil delegate:self];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error 
{
    [self dismissModalViewControllerAnimated:YES];
}

@end


