#import "TourModule.h"
#import "TourHomeViewController.h"
#import "TourWelcomeBackViewController.h"
#import "TourDataManager.h"

@implementation TourModule

- (id)initWithDictionary:(NSDictionary *)moduleDict {
  self = [super initWithDictionary:moduleDict];
  if (self) {        
    NSLog(@"tour: %@", moduleDict);
  }
  return self;
}

#pragma mark Data

- (NSArray *)objectModelNames {
    return [NSArray arrayWithObject:@"Tour"];
}


- (UIViewController *)modulePage:(NSString *)pageName 
                          params:(NSDictionary *)params {
    
    UIViewController *vc = nil;
    [[TourDataManager sharedManager] loadStopSummarys];
    
    if([pageName isEqualToString:LocalPathPageNameHome]) {
        UIViewController *rootVC;
        if([[TourDataManager sharedManager] getCurrentStop] == nil) {
            rootVC = 
            [[[TourHomeViewController alloc] 
              initWithNibName:@"TourHomeViewController" bundle:nil title:nil]
             autorelease];
        } else {
            rootVC = 
            [[[TourWelcomeBackViewController alloc] 
              initWithNibName:@"TourWelcomeBackViewController" bundle:nil
              title:@"Harvard Yard Tour"] autorelease];
        }
        vc = 
        [[[UINavigationController alloc] initWithRootViewController:rootVC]
         autorelease];
    }
    return vc;
}

@end

@implementation TourModule (UINavigationBarModification)

- (void)setUpNavigationBar:(UINavigationBar *)navBar {
    // Set the background tint color.
    navBar.tintColor = [UIColor colorWithWhite:0.85f alpha:1.0];    
}

- (void)setUpNavBarTitle:(NSString *)title navItem:(UINavigationItem *)navItem {
    // Set up the nav view with a title label so that the text color can be 
    // changed to dark gray.
    
    // http://stackoverflow.com/questions/599405/iphone-navigation-bar-title-text-color/621185#621185
    // this will appear as the title in the navigation bar
    CGRect frame = CGRectMake(0, 0, 400, 44);
    UILabel *label = [[[UILabel alloc] initWithFrame:frame] autorelease];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:20.0f];
    //label.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.5f];
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.textAlignment = UITextAlignmentCenter;
    label.textColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
    navItem.titleView = label;
    label.text = title;
    [label sizeToFit];
}

- (void)updateNavBarTitle:(NSString *)title navItem:(UINavigationItem *)navItem {
    UILabel *label = (UILabel *)navItem.titleView;
    if (!label) {
        [self setUpNavBarTitle:title navItem:navItem];
        label = (UILabel *)navItem.titleView;
    }
    label.text = title;
}

@end
