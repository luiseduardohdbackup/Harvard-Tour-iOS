#import "KGOUserSettingsManager.h"
#import "KGOUserSetting.h"

NSString * const KGOUserSettingPreferenceKey = @"ModuleSettings";

@interface KGOUserSetting (Setters)

- (void)_setKey:(NSString *)key;
- (void)_setTitle:(NSString *)title;
- (void)_setDefaultValue:(id)defaultValue;
- (void)_setOptions:(NSArray *)options;
- (void)_setUnrestricted:(BOOL)unrestricted;

@end


@implementation KGOUserSetting (Setters)

- (void)_setKey:(NSString *)key
{
    [_key release];
    _key = [key retain];
}

- (void)_setTitle:(NSString *)title
{
    [_title release];
    _title = [title retain];
}

- (void)_setDefaultValue:(id)defaultValue
{
    if (_defaultValue != defaultValue) {
        [_defaultValue release];
        _defaultValue = [defaultValue retain];
    }
}

- (void)_setOptions:(NSArray *)options
{
    if (_options != options) {
        [_options release];
        _options = [options retain];
    }
}

- (void)_setUnrestricted:(BOOL)unrestricted
{
    _unrestricted = unrestricted;
}

@end



@implementation KGOUserSettingsManager

+ (KGOUserSettingsManager *)sharedManager {
	static KGOUserSettingsManager *s_sharedManager = nil;
	if (s_sharedManager == nil) {
		s_sharedManager = [[KGOUserSettingsManager alloc] init];
	}
	return s_sharedManager;
}

- (NSArray *)settingsKeys
{
    // TODO: determine a way to sort
    return [_settings allKeys];
}

- (KGOUserSetting *)settingForKey:(NSString *)key
{
    return [_settings objectForKey:key];
}

- (NSUInteger)selectedOptionForKey:(NSString *)key
{
    KGOUserSetting *setting = [self settingForKey:key];
    return [setting.options indexOfObject:[self selectedValueDictForSetting:key]];
}

- (NSDictionary *)selectedValueDictForSetting:(NSString *)key
{
    KGOUserSetting *setting = [self settingForKey:key];
    if (setting.selectedValue) {
        return setting.selectedValue;
    } else {
        return setting.defaultValue;
    }
}

- (NSString *)selectedValueForSetting:(NSString *)key
{
    NSDictionary *dict = [self selectedValueDictForSetting:key];
    return [dict objectForKey:@"id"];
}

- (void)selectOption:(NSUInteger)option forSetting:(NSString *)key
{
    KGOUserSetting *setting = [self settingForKey:key];
    if (option < setting.options.count) {
        setting.selectedValue = [setting.options objectAtIndex:option];
    }
}

- (void)selectValue:(id)selectedValue forSetting:(NSString *)key
{
    // TODO: make sure all selectedValues are plist-compatible
    KGOUserSetting *setting = [self settingForKey:key];
    if (setting.unrestricted || [setting.options containsObject:selectedValue]) {
        setting.selectedValue = selectedValue;
    }
}

- (void)saveSettings
{
    NSMutableDictionary *plistSettings = [NSMutableDictionary dictionary];
    [_settings enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        KGOUserSetting *userSetting = (KGOUserSetting *)obj;
        if (userSetting.selectedValue) {
            [plistSettings setObject:userSetting.selectedValue forKey:key];
        }
    }];

    [[NSUserDefaults standardUserDefaults] setObject:plistSettings forKey:KGOUserSettingPreferenceKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)wipeSettings
{
    [_settings enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [(KGOUserSetting *)obj setSelectedValue:nil];
    }];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KGOUserSettingPreferenceKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id)init
{
    self = [super init];
    if (self) {
        _settings = [[NSMutableDictionary alloc] init];
        NSString *filename = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"plist"];
        NSDictionary *availableSettings = [NSDictionary dictionaryWithContentsOfFile:filename];
        NSDictionary *savedSettings = [[NSUserDefaults standardUserDefaults] objectForKey:KGOUserSettingPreferenceKey];

        __block NSMutableDictionary *theSettings = _settings;
        [availableSettings enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            KGOUserSetting *aSetting = [[[KGOUserSetting alloc] init] autorelease];
            [aSetting _setKey:key];
            [aSetting _setTitle:[obj objectForKey:@"title"]];

            NSArray *options = [obj objectForKey:@"options"];
            [aSetting _setOptions:options];
            
            NSNumber *unrestricted = [obj objectForKey:@"unrestricted"];
            if (unrestricted) {
                [aSetting _setUnrestricted:[unrestricted boolValue]];
            }

            for (NSDictionary *optionData in options) {
                NSNumber *isDefault = [optionData objectForKey:@"default"];
                if (isDefault && [isDefault boolValue]) {
                    [aSetting _setDefaultValue:optionData];
                    break;
                }
            }
            
            id savedSetting = [savedSettings objectForKey:key];
            if (savedSetting) {
                aSetting.selectedValue = savedSetting;
            }

            [theSettings setObject:aSetting forKey:key];
        }];
    }
    return self;
}

- (void)dealloc
{
    [_settings release];
    [super dealloc];
}

@end
