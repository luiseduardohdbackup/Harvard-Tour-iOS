#import "Foundation+KGOAdditions.h"
#import "AthleticsDataController.h"
#import "CoreDataManager.h"
#import "AthleticsModel.h"
#import "KGORequest.h"
#import "KGOSearchModel.h"
#define REQUEST_CATEGORIES_CHANGED 1
#define REQUEST_CATEGORIES_UNCHANGED 2
#define LOADMORE_LIMIT 10
#define CATEGORIES_COUNT 4
NSString * const AthleticsTagItem            = @"item";
NSString * const AthleticsTagTitle           = @"title";
NSString * const AthleticsTagAuthor          = @"author";
NSString * const AthleticsTagLink            = @"link";
NSString * const AthleticsTagStoryId         = @"GUID";
NSString * const AthleticsTagImage           = @"image";
NSString * const AthleticsTagSummary         = @"description";
NSString * const AthleticsTagPostDate        = @"pubDate";
NSString * const AthleticsTagHasBody         = @"hasBody";
NSString * const AthleticsTagBody            = @"body";

@implementation AthleticsDataController
@synthesize delegate;
@synthesize searchDelegate;
@synthesize moduleTag;
@synthesize currentStories = _currentStories;
@synthesize currentCategories = _currentCategories;
@synthesize currentCategory;
@synthesize storiesRequest;
@synthesize menuCategoryStoriesRequest;
@synthesize searchRequests = _searchRequests;

- (BOOL)requiresKurogoServer {
    return YES;
}

#pragma mark - KGORequestDelegate
- (void)requestWillTerminate:(KGORequest *)request {
    if (request == self.storiesRequest) {
        self.storiesRequest = nil;
    } else if ([self.searchRequests containsObject:request]) {
        [self.searchRequests removeObject:request];
        
        if (self.searchRequests.count == 0) { // all searches have completed
            if (_searchResults) {
                // TODO: use a user-facing string instead of module tag
                [self.searchDelegate receivedSearchResults:_searchResults forSource:self.moduleTag];
                [_searchResults release];
                _searchResults = nil;
            }
        }
    }
}

- (void)request:(KGORequest *)request didFailWithError:(NSError *)error {
    if (request == self.storiesRequest) {
        //NSString *categoryID = [request.getParams objectForKey:@"categoryID"];
        
        //if ([self.delegate respondsToSelector:@selector(storiesDidFailWithCategoryId:)]) {
        //    [self.delegate storiesDidFailWithCategoryId:categoryID];
        //}
        
        if ([self.delegate respondsToSelector:@selector(dataController:didFailWithCategoryId:)]) {
            [self.delegate dataController:self didFailWithCategoryId:self.currentCategory.category_id];
        }
        
        [[KGORequestManager sharedManager] showAlertForError:error request:request];
        
    } else if ([request.path isEqualToString:@"categories"]) {
        [[KGORequestManager sharedManager] showAlertForError:error request:request];
        
        // don't call -fetchCategories since it may issue another request
        NSArray *existingCategories = [self latestCategories];
        if (existingCategories && [self.delegate respondsToSelector:@selector(dataController:didRetrieveCategories:)]) {
            [self.delegate dataController:self didRetrieveCategories:existingCategories];
        }
    }
}

- (void)request:(KGORequest *)request didHandleResult:(NSInteger)returnValue {
    NSString *path = request.path;
    if (request == self.storiesRequest) {
        NSString *startId = [request.getParams objectForKey:@"start"];
        [self fetchStoriesForCategory:self.currentCategory.category_id startId:startId];
    } else if (request == self.menuCategoryStoriesRequest) {
        NSString *startId = [request.getParams objectForKey:@"start"];
        [self fetchMenuCategoryStories:self.currentCategory startId:startId];
        [self fetchMenuCategorySchedule:self.currentCategory startId:nil];
    } else if ([path isEqualToString:@"sports"]) {    
        [self fetchMenusForCategory:self.currentCategory.category_id startId:nil];
    }
}

- (void)request:(KGORequest *)request didReceiveResult:(id)result {
    if ([self.searchRequests containsObject:request]) {
        NSDictionary *resultDict = (NSDictionary *)result;
        NSArray *stories = [resultDict arrayForKey:@"stories"];
        if (_searchResults) {
            [_searchResults release];
        }
        _searchResults = [[NSMutableArray alloc] init];
        for (NSDictionary *storyDict in stories) {            
            AthleticsStory *story = [self storyWithDictionary:storyDict]; 
            [_searchResults addObject:story];
        }

       [[CoreDataManager sharedManager] saveData];
    }
}

- (void)request:(KGORequest *)request didMakeProgress:(CGFloat)progress {
    if (request == self.storiesRequest || request == self.menuCategoryStoriesRequest) {
        //NSString *categoryID = [request.getParams objectForKey:@"categoryID"];
        
        // TODO: see if progress value needs tweaking
        
        if ([self.delegate respondsToSelector:@selector(dataController:didMakeProgress:)]) {
            [self.delegate dataController:self didMakeProgress:progress];
        }
    }
}

- (void)requestDidReceiveResponse:(KGORequest *)request {
    
}

- (void)requestResponseUnchanged:(KGORequest *)request {
    [request cancel];
    
    NSDate *date = [self feedListModifiedDate];
    if (!date || [date timeIntervalSinceNow] + ATHLETICS_CATEGORY_EXPIRES_TIME < 0) {
        self.feedListModifiedDate = [NSDate date];
    }
    
    [self fetchCategories];
}

- (BOOL)canLoadMoreStories
{
    if ([self.currentCategory.moreStories intValue] > 0) {
        return YES;
    }
    return NO;
}

- (NSArray *)bookmarkedCategories
{
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"bookmarked == YES"];
    return [[CoreDataManager sharedManager] objectsForEntity:AthleticsCategoryEntityName matchingPredicate:pred];
}

#pragma mark - Serach

- (void)searchStories:(NSString *)searchTerms
{
    // cancel any previous search requests
    for (KGORequest *request in self.searchRequests) {
        [request cancel];
    }
    
    if (!_searchResults) {
        _searchResults = [[NSMutableArray alloc] init];
    } else {
        for (AthleticsStory *aStory in _searchResults) {
            aStory.searchResult = [NSNumber numberWithInt:0];
        }
        [_searchResults release];
        _searchResults = [[NSMutableArray alloc] init];
    }
    
    /*
     // remove all old search results
     for (NewsStory *story in [self latestSearchResults]) {
     story.searchResult = [NSNumber numberWithInt:0];
     }
     [[CoreDataManager sharedManager] saveData];
     */
    
    self.searchRequests = [NSMutableSet setWithCapacity:1];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:searchTerms forKey:@"filter"];
    [params setObject:@"0" forKey:@"x"];
    [params setObject:@"0" forKey:@"y"];
    [params setObject:@"topnews" forKey:@"section"];
        
    KGORequest *request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                          module:self.moduleTag
                                                                            path:@"search"
                                                                         version:1
                                                                          params:params];
    request.expectedResponseType = [NSDictionary class];
    [self.searchRequests addObject:request];
    [request connect];
}

- (NSDate *)feedListModifiedDate
{
    NSDictionary *modDates = [[NSUserDefaults standardUserDefaults] dictionaryForKey:FeedListModifiedDateKey];
    NSDate *result = [modDates dateForKey:self.moduleTag];
    if ([result isKindOfClass:[NSDate class]]) {
        return result;
    }
    return nil;
}

- (void)setFeedListModifiedDate:(NSDate *)date
{
    NSDictionary *modDates = [[NSUserDefaults standardUserDefaults] dictionaryForKey:FeedListModifiedDateKey];
    NSMutableDictionary *mutableModDates = modDates ? [[modDates mutableCopy] autorelease] : [NSMutableDictionary dictionary];
    if (self.moduleTag) {
        [mutableModDates setObject:date forKey:self.moduleTag];
    } else {
        NSLog(@"Warning: AthleticsDataController moduleTag not set, cannot save preferences");
    }
    [[NSUserDefaults standardUserDefaults] setObject:mutableModDates forKey:FeedListModifiedDateKey];
}

- (NSArray *)latestCategories
{
    if (!_currentCategories) {    
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isMainCategory = YES AND moduleTag = %@", self.moduleTag];
        NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey:@"sortOrder" ascending:YES] autorelease];
        NSSortDescriptor *catSort = [[[NSSortDescriptor alloc] initWithKey:@"category_id" ascending:YES] autorelease]; // compat
        NSArray *results = [[CoreDataManager sharedManager] objectsForEntity:AthleticsCategoryEntityName
                                                           matchingPredicate:predicate
                                                             sortDescriptors:[NSArray arrayWithObjects:sort, catSort, nil]];
        if (results.count) {
            self.currentCategories = results;
        }
    }
    
    return _currentCategories;
}

- (void)requestCategoriesFromLocal {
    if (!_currentCategories) {
        NSMutableArray *categories = [NSMutableArray array];
        
        NSMutableArray *newCategories = [NSMutableArray array];
        [newCategories addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                  @"0", @"id", 
                                  @"Top News", @"title", 
                                  @"news", @"path",
                                  @"sport", @"category",
                                  @"topnews", @"ivar",
                                  nil]];
        [newCategories addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                  @"1", @"id", 
                                  @"Men", @"title", 
                                  @"sports", @"path",
                                  @"gender", @"category",
                                  @"men", @"ivar",
                                  nil]];
        [newCategories addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                  @"2", @"id", 
                                  @"Women", @"title", 
                                  @"sports", @"path",
                                  @"gender", @"category",
                                  @"women", @"ivar",
                                  nil]];
        [newCategories addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                  @"3", @"id", 
                                  @"My Sports", @"title", 
                                  @"", @"path",
                                  @"", @"category",
                                  @"", @"ivar",
                                  nil]];
        
        for (NSDictionary *enumerator in newCategories) {
            [categories addObject:[self categoryWithDictionary:enumerator]];
        }
        [[CoreDataManager sharedManager] saveDataWithTemporaryMergePolicy:NSOverwriteMergePolicy];
        self.currentCategories = categories;
        if (_currentCategories && _currentCategories.count > 0) {
            if ([self.delegate respondsToSelector:@selector(dataController:didRetrieveCategories:)]) {
                [self.delegate dataController:self didRetrieveCategories:_currentCategories];
            }
        }
    }
}

- (void)fetchCategories
{
    NSDate *lastUpdate = [self feedListModifiedDate];
    NSArray *results = [self latestCategories];
    if (results.count) {
        if ([self.delegate respondsToSelector:@selector(dataController:didRetrieveCategories:)]) {
            [self.delegate dataController:self didRetrieveCategories:results];
        }
    }
    
    if (!results.count || !lastUpdate || [lastUpdate timeIntervalSinceNow] + ATHLETICS_CATEGORY_EXPIRES_TIME < 0) {
        [self requestCategoriesFromLocal];
    }    
}

- (void)fetchMenuCategorySchedule:(AthleticsCategory *)menuCategory startId:(NSString *)startId {
    NSManagedObjectContext *context = [[CoreDataManager sharedManager] managedObjectContext];
    if ([menuCategory managedObjectContext] != context) {
        menuCategory = (AthleticsCategory *)[context objectWithID:[menuCategory objectID]];
    }
    [[[CoreDataManager sharedManager] managedObjectContext] refreshObject:menuCategory mergeChanges:NO];
    if (!menuCategory.lastUpdated
        || [menuCategory.lastUpdated timeIntervalSinceNow] > ATHLETICS_CATEGORY_EXPIRES_TIME
        // TODO: make sure the following doesn't result an infinite loop if stories legitimately don't exist
        || !menuCategory.schedules.count)
    {
        DLog(@"last updated: %@", menuCategory.lastUpdated);
        [self requestMenuCategorySchedulesForCategory:menuCategory afterId:nil];
        return;
    }
    
    NSArray *results = [menuCategory.schedules sortedArrayUsingDescriptors:nil];
    
    if ([self.delegate respondsToSelector:@selector(dataController:didRetrieveSchedules:)]) {
        [self.delegate dataController:self didRetrieveSchedules:results];
    }
}

- (void)fetchMenuCategoryStories:(AthleticsCategory *)menuCategory startId:(NSString *)startId {
    if (![self.currentCategory isEqual:menuCategory]) {
        self.currentCategory = menuCategory;
    }
    NSManagedObjectContext *context = [[CoreDataManager sharedManager] managedObjectContext];
    if ([menuCategory managedObjectContext] != context) {
        menuCategory = (AthleticsCategory *)[context objectWithID:[menuCategory objectID]];
    }
    [[[CoreDataManager sharedManager] managedObjectContext] refreshObject:menuCategory mergeChanges:NO];
    if (!menuCategory.lastUpdated
        || [menuCategory.lastUpdated timeIntervalSinceNow] > ATHLETICS_CATEGORY_EXPIRES_TIME
        // TODO: make sure the following doesn't result an infinite loop if stories legitimately don't exist
        || !menuCategory.stories.count)
    {
        DLog(@"last updated: %@", menuCategory.lastUpdated);
        [self requestMenuCategoryStoriesForCategory:menuCategory afterId:nil];
        return;
    }
    
    NSSortDescriptor *dateSort = [[[NSSortDescriptor alloc] initWithKey:@"postDate" ascending:NO] autorelease];
    NSSortDescriptor *idSort = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:dateSort, idSort, nil];
    
    NSArray *results = [menuCategory.stories sortedArrayUsingDescriptors:sortDescriptors];
    
    if ([self.delegate respondsToSelector:@selector(dataController:didRetrieveStories:)]) {
        [self.delegate dataController:self didRetrieveStories:results];
    }
}

- (AthleticsCategory *)categoryWithId:(NSString *)categoryId {
    if ([self.currentCategory.category_id isEqualToString:categoryId]) {
        return self.currentCategory;
    }
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"category_id like %@", categoryId];
    NSArray *matches = [[self latestCategories] filteredArrayUsingPredicate:pred];
    if (matches.count > 1) {
        NSLog(@"warning: duplicate categories found for id %@", categoryId);
    }
    
    return [matches lastObject];
}

- (NSMutableArray *)bookmarksForCategoryId:(NSString *)categoryId {
    AthleticsCategory *aCategory= [self categoryWithId:categoryId];
    NSManagedObjectContext *context = [[CoreDataManager sharedManager] managedObjectContext];
    if ([aCategory managedObjectContext] != context) {
        aCategory = (AthleticsCategory *)[context objectWithID:[aCategory objectID]];
    }
    [[[CoreDataManager sharedManager] managedObjectContext] refreshObject:aCategory mergeChanges:NO];
    
    NSMutableArray *results = [NSMutableArray arrayWithArray:[aCategory.menu.categories sortedArrayUsingDescriptors:nil]];
    AthleticsCategory *theCategory = nil;
    for (theCategory in results) {
        if (theCategory.isMainCategory.boolValue) {
            break;
        }
    }
    [results removeObject:theCategory];
    
    NSMutableIndexSet *mutableIdxSet = [NSMutableIndexSet indexSet];
    for (int i = 0; i < results.count; i++) {
        if (!theCategory.bookmarked.boolValue) {
            [mutableIdxSet addIndex:i];
        }
    }
    [results removeObjectsAtIndexes:mutableIdxSet];
    return results;
}

- (void)fetchBookmarks
{
    if ([self.delegate respondsToSelector:@selector(dataController:didRetrieveBookmarkedCategories:)]) {
        [self.delegate dataController:self didRetrieveBookmarkedCategories:[self bookmarkedCategories]];
    }
}

- (void)fetchMenusForCategory:(NSString *)categoryId
                        startId:(NSString *)startId
{
    if (categoryId && ![categoryId isEqualToString:self.currentCategory.category_id]) {
        self.currentCategory = [self categoryWithId:categoryId];
    }
    
    NSManagedObjectContext *context = [[CoreDataManager sharedManager] managedObjectContext];
    if ([self.currentCategory managedObjectContext] != context) {
        self.currentCategory = (AthleticsCategory *)[context objectWithID:[self.currentCategory objectID]];
    }
    NSLog(@"%d",self.currentCategory.menu.categories.count);
    [[[CoreDataManager sharedManager] managedObjectContext] refreshObject:self.currentCategory mergeChanges:NO];
    if (!self.currentCategory.lastUpdated
        || -[self.currentCategory.lastUpdated timeIntervalSinceNow] > ATHLETICS_CATEGORY_EXPIRES_TIME
        // TODO: make sure the following doesn't result an infinite loop if stories legitimately don't exist
        || (self.currentCategory.menu.categories.count <= 0))
    {
        DLog(@"last updated: %@", self.currentCategory.lastUpdated);
        [self requestMenusForCategory:categoryId afterID:nil];
        return;
    }
    
    NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey:@"sortOrder" ascending:YES] autorelease];
    
    NSMutableArray *results = [NSMutableArray arrayWithArray:[self.currentCategory.menu.categories sortedArrayUsingDescriptors:[NSArray arrayWithObjects:sort, nil]]];
    AthleticsCategory *aCategory = nil;
    for (aCategory in results) {
        if (aCategory.isMainCategory.boolValue) {
            break;
        }
    }
    [results removeObject:aCategory];

    if ([self.delegate respondsToSelector:@selector(dataController:didRetrieveMenuCategories:)]) {
        [self.delegate dataController:self didRetrieveMenuCategories:results];
    }
}

- (void)fetchStoriesForCategory:(NSString *)categoryId
                        startId:(NSString *)startId
{
    if (categoryId && ![categoryId isEqualToString:self.currentCategory.category_id]) {
        self.currentCategory = [self categoryWithId:categoryId];
    }
    
    NSManagedObjectContext *context = [[CoreDataManager sharedManager] managedObjectContext];
    if ([self.currentCategory managedObjectContext] != context) {
        self.currentCategory = (AthleticsCategory *)[context objectWithID:[self.currentCategory objectID]];
    }
    [[[CoreDataManager sharedManager] managedObjectContext] refreshObject:self.currentCategory mergeChanges:NO];
    if (!self.currentCategory.lastUpdated
        || -[self.currentCategory.lastUpdated timeIntervalSinceNow] > ATHLETICS_CATEGORY_EXPIRES_TIME
        // TODO: make sure the following doesn't result an infinite loop if stories legitimately don't exist
        || !self.currentCategory.stories.count)
    {
        DLog(@"last updated: %@", self.currentCategory.lastUpdated);
        [self requestStoriesForCategory:categoryId afterId:nil];
        return;
    }
    
    NSSortDescriptor *dateSort = [[[NSSortDescriptor alloc] initWithKey:@"postDate" ascending:NO] autorelease];
    NSSortDescriptor *idSort = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:dateSort, idSort, nil];
    
    NSArray *results = [self.currentCategory.stories sortedArrayUsingDescriptors:sortDescriptors];
    
    if ([self.delegate respondsToSelector:@selector(dataController:didRetrieveStories:)]) {
        [self.delegate dataController:self didRetrieveStories:results];
    }
}

- (AthleticsCategory *)categoryWithDictionary:(NSDictionary *)categoryDict
{
    AthleticsCategory *category = nil;
    NSString *categoryId = [categoryDict nonemptyStringForKey:@"id"];
    if (categoryId) {
        category = [self categoryWithId:categoryId];
        if (!category) {
            category = [[CoreDataManager sharedManager] insertNewObjectForEntityForName:AthleticsCategoryEntityName];
            category.moduleTag = self.moduleTag;
            category.category_id = categoryId;
        }
        category.title = [categoryDict nonemptyStringForKey:@"title"];
        category.category = [categoryDict nonemptyStringForKey:@"category"];
        category.path = [categoryDict nonemptyStringForKey:@"path"];
        category.ivar = [categoryDict nonemptyStringForKey:@"ivar"];
        category.isMainCategory = [NSNumber numberWithBool:YES];
        category.moreStories = [NSNumber numberWithInt:-1];
        category.nextSeekId = [NSNumber numberWithInt:0];
    }
    return category;
}

- (AthleticsCategory *)menuCategoryWithDictionary:(NSDictionary *)menuDict 
withKey:(NSString *)key{
    AthleticsCategory *category = nil;
    if (!category) {
        category = [[CoreDataManager sharedManager] insertNewObjectForEntityForName:AthleticsCategoryEntityName];
        category.moduleTag = self.moduleTag;
        category.category_id = @"";
    }
    category.title = [menuDict nonemptyStringForKey:@"title"];
    category.category = @"sport";
    category.path = @"news";
    category.ivar = key;
    category.bookmarked = [NSNumber numberWithBool:NO];
    category.isMainCategory = [NSNumber numberWithBool:NO];
    category.moreStories = [NSNumber numberWithInt:-1];
    category.nextSeekId = [NSNumber numberWithInt:0];
    return category;
}

- (void)requestMenusForCategory:(NSString *)categoryID afterID:(NSString *)afterId {
    if (![categoryID isEqualToString:self.currentCategory.category_id]) {
        self.currentCategory = [self categoryWithId:categoryID];
    }
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            self.currentCategory.ivar, self.currentCategory.category,
                            nil];
    
    KGORequest *request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                          module:self.moduleTag
                                                                            path:self.currentCategory.path
                                                                         version:1
                                                                          params:params];
    self.storiesRequest = nil;
    
    __block AthleticsDataController *blockSelf = self;
    __block AthleticsCategory *category = self.currentCategory;
    [request connectWithCallback:^(id result) {
        NSDictionary *resultDict = (NSDictionary *)result;
        NSManagedObjectContext *context = [[CoreDataManager sharedManager] managedObjectContext];
        if ([category managedObjectContext] != context) {
            category = (AthleticsCategory *)[context objectWithID:[category objectID]];
        }
        [[[CoreDataManager sharedManager] managedObjectContext] refreshObject:category mergeChanges:NO];
        category.menu = [blockSelf menuWithDictionary:resultDict];
        NSMutableSet *mutableCategories = [category.menu mutableSetValueForKey:@"categories"];
        id sports = [resultDict objectForKey:@"sports"];
        AthleticsCategory *menuCategory = nil;
        if ([sports isKindOfClass:[NSArray class]]) {
            sports = [resultDict arrayForKey:@"sports"];
            int i = 0;
            for(NSDictionary *enu in sports) {
                 menuCategory = [blockSelf menuCategoryWithDictionary:enu withKey:[enu objectForKey:@"key"]];
                    menuCategory.sortOrder = [NSNumber numberWithInt: i++];
                if (menuCategory) {
                    [mutableCategories addObject:menuCategory];
                }
            }
        } else if ([sports isKindOfClass:[NSDictionary class]]){
            sports = [resultDict dictionaryForKey:@"sports"];
            __block int i = 0;
            [sports enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                AthleticsCategory *menuCategory = [blockSelf menuCategoryWithDictionary:obj withKey:key];
                menuCategory.sortOrder = [NSNumber numberWithInt: i++];
                if (menuCategory) {
                    [mutableCategories addObject:menuCategory];
                }
            }];
        } else {
            return 0;
        }
        category.lastUpdated = [NSDate date];
        [[CoreDataManager sharedManager] saveData];
        return 1;
    }];
}

- (void)requestStoriesForCategory:(NSString *)categoryId afterId:(NSString *)afterId
{
    // TODO: signal that loading progress is 0
    if (![categoryId isEqualToString:self.currentCategory.category_id]) {
        self.currentCategory = [self categoryWithId:categoryId];
    }
    
    NSInteger start = 0;
    if (afterId) {
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"identifier = %@", afterId];
        AthleticsStory *story = [[self.currentStories filteredArrayUsingPredicate:pred] lastObject];
        if (story) {
            NSInteger index = [self.currentStories indexOfObject:story];
            if (index != NSNotFound) {
                start = ++index;
            }
        }
    }
    
    NSInteger moreStories = [self.currentCategory.moreStories integerValue];
    NSInteger limit = (moreStories >= 0 && moreStories < LOADMORE_LIMIT) ? moreStories : LOADMORE_LIMIT;
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            self.currentCategory.ivar, self.currentCategory.category,
                            [NSString stringWithFormat:@"%d", start], @"start",
                            [NSString stringWithFormat:@"%d", limit], @"limit",
                            nil];
    
    KGORequest *request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                          module:self.moduleTag
                                                                            path:self.currentCategory.path
                                                                         version:1
                                                                          params:params];
    self.storiesRequest = request;
    
    __block AthleticsDataController *blockSelf = self;
    __block AthleticsCategory *category = self.currentCategory;
    [request connectWithCallback:^(id result) {
        NSDictionary *resultDict = (NSDictionary *)result;
        NSArray *stories = [resultDict arrayForKey:@"stories"];
        // need to bring category to local context
        // http://stackoverflow.com/questions/1554623/illegal-attempt-to-establish-a-relationship-xyz-between-objects-in-different-co
        AthleticsCategory *mergedCategory = nil;
        NSMutableSet *mutableStories = nil;
        for (NSDictionary *storyDict in stories) {            
            AthleticsStory *story = [blockSelf storyWithDictionary:storyDict];            
            if (!mergedCategory) {
                mergedCategory = (AthleticsCategory *)[[story managedObjectContext] objectWithID:[category objectID]];
            }
            if (!mutableStories) {
                mutableStories = [mergedCategory mutableSetValueForKey:@"stories"];
            }
            if (mutableStories) {
                [mutableStories addObject:story];
            }
        }
        mergedCategory.moreStories = [resultDict numberForKey:@"moreStories"];
        mergedCategory.lastUpdated = [NSDate date];
        [[CoreDataManager sharedManager] saveData];
        return (NSInteger)[stories count];
    }];
}

- (void)requestMenuCategorySchedulesForCategory:(AthleticsCategory *)menuCategory afterId:(NSString *)afterId
{
    // TODO: signal that loading progress is 0
    //    if (![categoryId isEqualToString:self.currentCategory.category_id]) {
    //        self.currentCategory = [self categoryWithId:categoryId];
    //    }
    //    
    //    NSInteger start = 0;
    //    if (afterId) {
    //        NSPredicate *pred = [NSPredicate predicateWithFormat:@"identifier = %@", afterId];
    //        AthleticsStory *story = [[self.currentStories filteredArrayUsingPredicate:pred] lastObject];
    //        if (story) {
    //            NSInteger index = [self.currentStories indexOfObject:story];
    //            if (index != NSNotFound) {
    //                start = index;
    //            }
    //        }
    //    }
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            menuCategory.ivar, menuCategory.category,
                            nil];
    
    KGORequest *request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                          module:self.moduleTag
                                                                            path:@"schedule"
                                                                         version:1
                                                                          params:params];
    self.menuCategoryStoriesRequest = request;
    
    __block AthleticsDataController *blockSelf = self;
    __block AthleticsCategory *category = menuCategory;
    [request connectWithCallback:^(id result) {
        NSDictionary *resultDict = (NSDictionary *)result;
        NSArray *schedules = [resultDict arrayForKey:@"results"];
        NSManagedObjectContext *context = [[CoreDataManager sharedManager] managedObjectContext];
        if ([category managedObjectContext] != context) {
            category = (AthleticsCategory *)[context objectWithID:[category objectID]];
        }
        [[[CoreDataManager sharedManager] managedObjectContext] refreshObject:category mergeChanges:NO];
        // need to bring category to local context
        // http://stackoverflow.com/questions/1554623/illegal-attempt-to-establish-a-relationship-xyz-between-objects-in-different-co
        NSMutableSet *mutableSchedules = [category mutableSetValueForKey:@"schedules"];
        for (NSDictionary *scheduleDict in schedules) {            
            AthleticsSchedule *schedule = [blockSelf scheduleWithDictionary:scheduleDict];            
            schedule.category = category;
            [mutableSchedules addObject:schedule];
        }
        category.lastUpdated = [NSDate date];
        [[CoreDataManager sharedManager] saveData];
        return (NSInteger)[schedules count];
    }];
}

- (void)requestMenuCategoryStoriesForCategory:(AthleticsCategory *)menuCategory afterId:(NSString *)afterId
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	@synchronized(self) 
    {
        // TODO: signal that loading progress is 0
        if (!self.currentCategory || ![self.currentCategory isEqual:menuCategory]) {
            self.currentCategory = menuCategory;
        }
        
        NSInteger start = 0;
        if (afterId) {
            NSPredicate *pred = [NSPredicate predicateWithFormat:@"identifier = %@", afterId];
            AthleticsStory *story = [[self.currentStories filteredArrayUsingPredicate:pred] lastObject];
            if (story) {
                NSInteger index = [self.currentStories indexOfObject:story];
                if (index != NSNotFound) {
                    start = ++index;
                }
            }
        }
        
        NSInteger moreStories = [self.currentCategory.moreStories integerValue];
        NSInteger limit = (moreStories >= 0 && moreStories < LOADMORE_LIMIT) ? moreStories : LOADMORE_LIMIT;
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                self.currentCategory.ivar, self.currentCategory.category,
                                [NSString stringWithFormat:@"%d", start], @"start",
                                [NSString stringWithFormat:@"%d", limit], @"limit",
                                nil];
        
        KGORequest *request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                              module:self.moduleTag
                                                                                path:menuCategory.path
                                                                             version:1
                                                                              params:params];
        self.menuCategoryStoriesRequest = request;
        
        __block AthleticsDataController *blockSelf = self;
        __block AthleticsCategory *category = menuCategory;
        [request connectWithCallback:^(id result) {
            NSDictionary *resultDict = (NSDictionary *)result;
            NSArray *stories = [resultDict arrayForKey:@"stories"];
            // need to bring category to local context
            // http://stackoverflow.com/questions/1554623/illegal-attempt-to-establish-a-relationship-xyz-between-objects-in-different-co
            AthleticsCategory *mergedCategory = nil;
            for (NSDictionary *storyDict in stories) {            
                AthleticsStory *story = [blockSelf storyWithDictionary:storyDict];            
                if (!mergedCategory) {
                    mergedCategory = (AthleticsCategory *)[[story managedObjectContext] objectWithID:[category objectID]];
                }
                NSMutableSet *mutableStories = [mergedCategory mutableSetValueForKey:@"stories"];
                if (mutableStories) {
                    [mutableStories addObject:story];
                }
            }
            mergedCategory.moreStories = [resultDict numberForKey:@"moreStories"];
            mergedCategory.lastUpdated = [NSDate date];
            [[CoreDataManager sharedManager] saveData];
            return (NSInteger)[stories count];
        }];
	}
	[pool release];    
}

- (AthleticsMenu *)menuWithDictionary:(NSDictionary *)menuDict {
    AthleticsMenu *menu = [[CoreDataManager sharedManager] insertNewObjectForEntityForName:AthleticsMenuEntityName];
    menu.sportTitle = [menuDict objectForKey:@"sporttitle"];
    return menu;
}

- (AthleticsStory *)storyWithDictionary:(NSDictionary *)storyDict {
    // use existing story if it's already in the db
    NSString *GUID = [storyDict nonemptyStringForKey:AthleticsTagStoryId];
    AthleticsStory *story = [[CoreDataManager sharedManager] uniqueObjectForEntity:AthleticsStoryEntityName attribute:@"identifier" value:GUID];
    // otherwise create new
    if (!story) {
        story = (AthleticsStory *)[[CoreDataManager sharedManager] insertNewObjectForEntityForName:AthleticsStoryEntityName];
        story.identifier = GUID;
    }
    
    story.moduleTag = self.moduleTag;
    
    double unixtime = [[storyDict objectForKey:@"pubDate"] doubleValue];
    NSDate *postDate = [NSDate dateWithTimeIntervalSince1970:unixtime];
    
    story.postDate = postDate;
    story.title = [storyDict nonemptyStringForKey:AthleticsTagTitle];
    story.link = [storyDict nonemptyStringForKey:AthleticsTagLink];
    story.author = [storyDict nonemptyStringForKey:AthleticsTagAuthor];
    story.summary = [storyDict nonemptyStringForKey:AthleticsTagSummary];
    story.hasBody = [NSNumber numberWithBool:[storyDict boolForKey:AthleticsTagHasBody]];
    story.body = [storyDict nonemptyStringForKey:AthleticsTagBody];
    NSDictionary *imageDict = [storyDict dictionaryForKey:AthleticsTagImage];
    if (imageDict) {
        // an old thumb may already exist
        // in which case do not create a new one
        if (!story.thumbImage) {
            story.thumbImage = [[CoreDataManager sharedManager] insertNewObjectForEntityForName:AthleticsImageEntityName];
        }
        story.thumbImage.url = [imageDict nonemptyStringForKey:@"src"];
        story.thumbImage.thumbParent = story;
    } else {
        story.thumbImage = nil;
    }
    return story;
}

- (AthleticsSchedule *)scheduleWithDictionary:(NSDictionary *)scheduleDict {
    // use existing schedule if it's already in the db
    NSString *ScheduleID = [scheduleDict nonemptyStringForKey:@"id"];
    AthleticsSchedule *schedule = [[CoreDataManager sharedManager] uniqueObjectForEntity:AthleticsScheduleEntityName attribute:@"schedule_id" value:ScheduleID];
    if (!schedule) {
        schedule = (AthleticsSchedule *)[[CoreDataManager sharedManager] insertNewObjectForEntityForName:AthleticsScheduleEntityName];
        schedule.schedule_id = ScheduleID;
    }

    schedule.allDay = [NSNumber numberWithBool:[scheduleDict boolForKey:@"allday"]];
    schedule.descriptionString = [scheduleDict nonemptyStringForKey:@"description"];
    schedule.gender = [scheduleDict nonemptyStringForKey:@"gender"];
    schedule.link = [scheduleDict nonemptyStringForKey:@"link"];;
    schedule.location = [scheduleDict nonemptyStringForKey:@"location"];
    schedule.locationLabel = [scheduleDict nonemptyStringForKey:@"locationLabel"];
    schedule.pastStatus = [NSNumber numberWithBool:[scheduleDict boolForKey:@"pastStatus"]];
    schedule.sport = [scheduleDict nonemptyStringForKey:@"sport"];
    schedule.sportName = [scheduleDict nonemptyStringForKey:@"sportName"];
    schedule.start = [NSNumber numberWithDouble:[[scheduleDict nonemptyStringForKey:@"start"] doubleValue]] ;
    schedule.title = [scheduleDict nonemptyStringForKey:@"title"];
    return schedule;
}


- (void)dealloc {
    self.moduleTag = nil;
    self.storiesRequest = nil;
    self.menuCategoryStoriesRequest = nil;
    [_searchResults release];_searchResults = nil;
    [super dealloc];
}
@end
