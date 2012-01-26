#import "KGOTheme.h"
#import "UIKit+KGOAdditions.h"
#import "Foundation+KGOAdditions.h"
#import "KGOUserSettingsManager.h"

NSString * const KGOAccessoryTypeNone = @"None";
NSString * const KGOAccessoryTypeBlank = @"Blank";
NSString * const KGOAccessoryTypeChevron = @"Chevron";
NSString * const KGOAccessoryTypeCheckmark = @"Check";
NSString * const KGOAccessoryTypePhone = @"Phone";
NSString * const KGOAccessoryTypePeople = @"People";
NSString * const KGOAccessoryTypeMap = @"Map";
NSString * const KGOAccessoryTypeEmail = @"Email";
NSString * const KGOAccessoryTypeExternal = @"External";


NSString * const KGOThemePropertyBodyText = @"BodyText";
NSString * const KGOThemePropertySmallPrint = @"SmallPrint";
NSString * const KGOThemePropertyContentTitle = @"ContentTitle";
NSString * const KGOThemePropertyContentSubtitle = @"ContentSubtitle";
NSString * const KGOThemePropertyPageTitle = @"PageTitle";
NSString * const KGOThemePropertyPageSubtitle = @"PageSubtitle";
NSString * const KGOThemePropertyCaption = @"Caption";
NSString * const KGOThemePropertyByline = @"Byline";
NSString * const KGOThemePropertyMediaListTitle = @"MediaListTitle";
NSString * const KGOThemePropertyMediaListSubtitle = @"MediaListSubtitle";
NSString * const KGOThemePropertySportListTitle = @"SportListTitle";
NSString * const KGOThemePropertySportListSubtitle = @"SportListSubtitle";
NSString * const KGOThemePropertyNavListTitle = @"NavListTitle";
NSString * const KGOThemePropertyNavListSubtitle = @"NavListSubtitle";
NSString * const KGOThemePropertyNavListLabel = @"NavListLabel";
NSString * const KGOThemePropertyNavListValue = @"NavListValue";
NSString * const KGOThemePropertyScrollTab = @"ScrollTab";
NSString * const KGOThemePropertyScrollTabSelected = @"ScrollTabSelected";
NSString * const KGOThemePropertySectionHeader = @"SectionHeader";
NSString * const KGOThemePropertySectionHeaderGrouped = @"SectionHeaderGrouped";
NSString * const KGOThemePropertyTab = @"Tab";
NSString * const KGOThemePropertyTabSelected = @"TabSelected";
NSString * const KGOThemePropertyTabActive = @"TabActive";

@interface KGOTheme (Private)

- (UIColor *)matchBackgroundColorWithLabel:(NSString *)label;

@end



@implementation KGOTheme

static KGOTheme *s_sharedTheme = nil;

+ (KGOTheme *)sharedTheme {
    if (s_sharedTheme == nil) {
        s_sharedTheme = [[KGOTheme alloc] init];
    }
    return s_sharedTheme;
}

#pragma mark Fonts

- (UIFont *)defaultFont
{
    return [UIFont fontWithName:[self defaultFontName] size:[self defaultFontSize]];
}

- (UIFont *)defaultBoldFont
{
    NSString *fontName = [self defaultFontName];
    CGFloat size = [self defaultFontSize];
    UIFont *font = [UIFont fontWithName:[NSString stringWithFormat:@"%@-Bold", fontName]
                                   size:size];
    if (!font) {
        font = [UIFont fontWithName:fontName size:size];
    }
    return font;
}

- (NSString *)defaultFontName
{
    NSString *fontName = [fontDict nonemptyStringForKey:@"DefaultFont"];
    if (!fontName) {
        fontName = [[UIFont systemFontOfSize:[UIFont systemFontSize]] fontName];
    }
    return fontName;
}

- (CGFloat)defaultFontSize
{
    CGFloat fontSize = [fontDict floatForKey:@"DefaultFontSize"];
    if (!fontSize) {
        fontSize = [UIFont systemFontSize];
    }
    return fontSize;
}

- (UIFont *)fontForThemedProperty:(NSString *)themeProperty
{
    UIFont *font = nil;
    
    NSString *fontName = nil;
    CGFloat fontSize = [self defaultFontSize];
    
    NSDictionary *fontInfo = [fontDict objectForKey:themeProperty];
    if (fontInfo) {
        fontName = [fontInfo nonemptyStringForKey:@"font"];
        if (!fontName) {
            fontName = [self defaultFontName];
        }
        fontSize += [fontInfo floatForKey:@"size"];
        if ([fontInfo boolForKey:@"bold"]) {
            font = [UIFont fontWithName:[NSString stringWithFormat:@"%@-Bold", fontName]
                                   size:fontSize];
        }
        if (!font) {
            font = [UIFont fontWithName:fontName size:fontSize];
        }
        
    } else {
        font = [UIFont fontWithName:[self defaultFontName] size:fontSize];
    }
    
    if (!font) {
        font = [UIFont systemFontOfSize:fontSize];
    }
    
    return font;
}

- (UIColor *)textColorForThemedProperty:(NSString *)themeProperty
{
    UIColor *color = nil;
    NSDictionary *fontInfo = [fontDict objectForKey:themeProperty];
    if (fontInfo) {
        NSString *hexString = [fontInfo objectForKey:@"color"];
        if (hexString) {
            color = [UIColor colorWithHexString:hexString];
        }
    }
    
    if (!color) {
        color = [UIColor blackColor];
    }
    
    return color;
}

#pragma mark - Universal colors

- (UIColor *)matchBackgroundColorWithLabel:(NSString *)label {
    UIColor *color = nil;
    NSString *colorString = [[themeDict objectForKey:@"Colors"] objectForKey:label];
    if (colorString) {
        // check if there is a valid image first
        UIImage *image = [UIImage imageWithPathName:colorString];
        if (image) {
            // TODO: if we get to this point we need to make sure iphone/ipad resources are distinguished
            color = [UIColor colorWithPatternImage:image];
        } else {
            color = [UIColor colorWithHexString:colorString];
        }
    }
    return color;
}

- (UIColor *)linkColor {
    UIColor *color = [self matchBackgroundColorWithLabel:@"Link"];
    if (!color)
        color = [UIColor blueColor];
    return color;
}

- (UIColor *)backgroundColorForApplication {
    UIColor *color = [self matchBackgroundColorWithLabel:@"AppBackground"];
    if (!color)
        color = [UIColor whiteColor];
    return color;
}

#pragma mark View colors

// this one can be nil
// TODO: make nil/non-nil distinction more transparent
- (UIColor *)tintColorForToolbar {
    UIColor *color = [self matchBackgroundColorWithLabel:@"ToolbarTintColor"];
    return color;
}

- (UIColor *)tintColorForSearchBar {
    UIColor *color = [self matchBackgroundColorWithLabel:@"SearchBarTintColor"];
    return color;
}

- (UIColor *)tintColorForNavBar {
    UIColor *color = [self matchBackgroundColorWithLabel:@"NavBarTintColor"];
    return color;
}

- (UIColor *)backgroundColorForDatePager {
    UIColor *color = [self matchBackgroundColorWithLabel:@"DatePagerBackground"];
    if (!color) {
        color = [UIColor grayColor];
    }
    return color;
}

#pragma mark Table view colors

- (UIColor *)tintColorForSelectedCell {
    UIColor *color = [self matchBackgroundColorWithLabel:@"NavListSelectionColor"];
    return color;
}

- (UIColor *)backgroundColorForPlainSectionHeader {
    UIColor *color = [self matchBackgroundColorWithLabel:@"PlainSectionHeaderBackground"];
    if (!color)
        color = [UIColor blackColor];
    return color;
}

- (UIColor *)tableSeparatorColor {
    NSString *tableSeperatorColorString = [[themeDict objectForKey:@"Colors"] objectForKey:@"TableSeparator"];
    if (tableSeperatorColorString) {
        return [UIColor colorWithHexString:tableSeperatorColorString];
    } else {
        return [UIColor colorWithWhite:0.5 alpha:1.0];
    }
}

#pragma mark - Background Images

- (UIImage *)titleImageForNavBar {
    NSString *imageName = [[themeDict objectForKey:@"Images"] objectForKey:@"NavBarTitle"];
    if (imageName)
        return [UIImage imageWithPathName:imageName];
    return nil;
}

- (UIImage *)backgroundImageForToolbar {
    NSString *imageName = [[themeDict objectForKey:@"Images"] objectForKey:@"ToolbarBackground"];
    if (imageName)
        return [UIImage imageWithPathName:imageName];
    return nil;
}

- (UIImage *)backgroundImageForNavBar {
    NSString *imageName = [[themeDict objectForKey:@"Images"] objectForKey:@"NavBarBackground"];
    if (imageName)
        return [UIImage imageWithPathName:imageName];
    return nil;
}

- (UIImage *)backgroundImageForSearchBar {
    NSString *imageName = [[themeDict objectForKey:@"Images"] objectForKey:@"SearchBarBackground"];
    if (imageName)
        return [UIImage imageWithPathName:imageName];
    return nil;
}

- (UIImage *)backgroundImageForSearchBarDropShadow {
    NSString *imageName = [[themeDict objectForKey:@"Images"] objectForKey:@"SearchBarDropShadow"];
    if (imageName)
        return [UIImage imageWithPathName:imageName];
    return nil;
}

#pragma mark - Enumerated styles

- (UIBarStyle)defaultNavBarStyle
{
    // TODO: create a config setting for this
    return UIBarStyleBlack;
}

#pragma mark - Homescreen

- (NSDictionary *)homescreenConfig
{
    return [themeDict dictionaryForKey:@"HomeScreen"];
}

#pragma mark - UITableViewCell

- (UIColor *)backgroundColorForSecondaryCell {
    UIColor *color = [self matchBackgroundColorWithLabel:@"SecondaryCellBackground"];
    if (!color)
        color = [UIColor whiteColor];
    return color;
}

// provide None, Blank, and Chevron by default.
// other styles can be defined in theme plist
- (UIImageView *)accessoryViewForType:(NSString *)accessoryType {
    
    static NSDictionary *CellAccessoryImages = nil;
    static NSDictionary *CellAccessoryImagesHighlighted = nil;
    
    if (CellAccessoryImages == nil) {
        CellAccessoryImages = [[NSDictionary alloc] initWithObjectsAndKeys:
                               @"common/action-blank", KGOAccessoryTypeBlank,
                               @"common/action-checkmark", KGOAccessoryTypeCheckmark,
                               @"common/action-arrow", KGOAccessoryTypeChevron,
                               @"common/action-phone", KGOAccessoryTypePhone,
                               @"common/action-people", KGOAccessoryTypePeople,
                               @"common/action-map", KGOAccessoryTypeMap,
                               @"common/action-email", KGOAccessoryTypeEmail,
                               @"common/action-external", KGOAccessoryTypeExternal,
                               nil];
    }
    if (CellAccessoryImagesHighlighted == nil) {
        CellAccessoryImagesHighlighted = [[NSDictionary alloc] initWithObjectsAndKeys:
                                          @"common/action-checkmark-highlight", KGOAccessoryTypeCheckmark,
                                          @"common/action-arrow-highlight", KGOAccessoryTypeChevron,
                                          @"common/action-phone-highlight", KGOAccessoryTypePhone,
                                          @"common/action-people-highlight", KGOAccessoryTypePeople,
                                          @"common/action-map-highlight", KGOAccessoryTypeMap,
                                          @"common/action-email-highlight", KGOAccessoryTypeEmail,
                                          @"common/action-external-highlight", KGOAccessoryTypeExternal,
                                          nil];
    }
    
    if (accessoryType && ![accessoryType isEqualToString:KGOAccessoryTypeNone]) {
        UIImage *image = [UIImage imageWithPathName:[CellAccessoryImages objectForKey:accessoryType]];
        UIImage *highlightedImage = [UIImage imageWithPathName:[CellAccessoryImagesHighlighted objectForKey:accessoryType]];
        if (image) {
            if (highlightedImage) {
                return [[[UIImageView alloc] initWithImage:image highlightedImage:highlightedImage] autorelease];
            }
            return [[[UIImageView alloc] initWithImage:image] autorelease];
        }
    }
    return nil;
}

#pragma mark - Private

- (void)loadFontPreferences
{
    NSMutableDictionary *mutableFontDict = [[[themeDict objectForKey:@"Fonts"] mutableCopy] autorelease];
    
    CGFloat fontSize = [[mutableFontDict objectForKey:@"DefaultFontSize"] floatValue];
    if (!fontSize) {
        fontSize = [UIFont systemFontSize];
    }
    
    NSString *fontSizePref = [[KGOUserSettingsManager sharedManager] selectedValueForSetting:@"FontSize"];
    if (fontSizePref) {
        if ([fontSizePref isEqualToString:@"Tiny"]) {
            fontSize -= 4;
        } else if ([fontSizePref isEqualToString:@"Small"]) {
            fontSize -= 2;
        } else if ([fontSizePref isEqualToString:@"Large"]) {
            fontSize += 2;
        } else if ([fontSizePref isEqualToString:@"Huge"]) {
            fontSize += 4;
        }

        [mutableFontDict setObject:[NSNumber numberWithFloat:fontSize] forKey:@"DefaultFontSize"];
    }

    NSString *fontPref = [[KGOUserSettingsManager sharedManager] selectedValueForSetting:@"Font"];
    if (fontPref) {
        UIFont *font = [UIFont fontWithName:fontPref size:fontSize];
        if (font) {
            [mutableFontDict setObject:fontPref forKey:@"DefaultFont"];
        }
    }

    [fontDict copy];
    fontDict = [mutableFontDict copy];
}

- (void)userDefaultsDidChange:(NSNotification *)aNotification
{
    [self loadFontPreferences];
}

#pragma mark -

- (id)init
{
    self = [super init];
    if (self) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            NSString *file = [[NSBundle mainBundle] pathForResource:@"ThemeConfig-iPad" ofType:@"plist"];
            themeDict = [[NSDictionary alloc] initWithContentsOfFile:file];
        }
        if (!themeDict) {
            NSString *file = [[NSBundle mainBundle] pathForResource:@"ThemeConfig" ofType:@"plist"];
            themeDict = [[NSDictionary alloc] initWithContentsOfFile:file];
        }
        [self loadFontPreferences];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userDefaultsDidChange:)
                                                     name:KGOUserPreferencesDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	fontDict = nil;
    [themeDict release];
    [super dealloc];
}

@end
