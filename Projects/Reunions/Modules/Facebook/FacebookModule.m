#import "FacebookModule.h"
#import "FacebookPhotosViewController.h"
#import "KGOSocialMediaController.h"
#import "KGOHomeScreenWidget.h"
#import "KGOTheme.h"

@implementation FacebookModule

- (UIViewController *)modulePage:(NSString *)pageName params:(NSDictionary *)params {
    UIViewController *vc = nil;
    if ([pageName isEqualToString:LocalPathPageNameHome]) {
        vc = [[[FacebookPhotosViewController alloc] init] autorelease];
    }
    return vc;
}

- (void)launch {
    [super launch];
    [[KGOSocialMediaController sharedController] startupFacebook];
}

- (void)terminate {
    [super terminate];
    [[KGOSocialMediaController sharedController] shutdownFacebook];
}

#pragma mark View on home screen



- (NSArray *)widgetViews {
    NSString *title = @"This is a fake Facebook widget";
    
    UIFont *font = [[KGOTheme sharedTheme] fontForBodyText];
    CGSize size = [title sizeWithFont:font constrainedToSize:CGSizeMake(140, 200) lineBreakMode:UILineBreakModeWordWrap];
    
    NSMutableArray *widgets = [NSMutableArray array];
    
    UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(5, 5, size.width, size.height)] autorelease];
    label.numberOfLines = 0;
    label.lineBreakMode = UILineBreakModeWordWrap;
    label.font = font;
    label.text = title;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor blackColor];
    
    KGOHomeScreenWidget *widget = [[[KGOHomeScreenWidget alloc] initWithFrame:CGRectMake(0, 0, size.width + 10, size.height + 10)] autorelease];
    [widget addSubview:label];
    widget.gravity = KGOLayoutGravityBottomLeft;
    
    [widgets addObject:widget];

    return widgets;
}

#pragma mark Social media controller

- (NSSet *)socialMediaTypes {
    return [NSSet setWithObject:KGOSocialMediaTypeFacebook];
}

- (NSDictionary *)userInfoForSocialMediaType:(NSString *)mediaType {
    if ([mediaType isEqualToString:KGOSocialMediaTypeFacebook]) {
        return [NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:
                                                   @"read_stream",
                                                   @"offline_access",
                                                   @"user_groups",
                                                   nil]
                                           forKey:@"permissions"];
    }
    return nil;
}

@end
