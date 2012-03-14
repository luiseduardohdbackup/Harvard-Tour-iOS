#import "NewsDataController.h"
#import "CoreDataManager.h"
#import "Foundation+KGOAdditions.h"
#import "KGORequest.h"


#define REQUEST_CATEGORIES_CHANGED 1
#define REQUEST_CATEGORIES_UNCHANGED 2
#define LOADMORE_LIMIT 10

NSString * const NewsTagItem            = @"item";
NSString * const NewsTagTitle           = @"title";
NSString * const NewsTagAuthor          = @"author";
NSString * const NewsTagLink            = @"link";
NSString * const NewsTagStoryId         = @"GUID";
NSString * const NewsTagImage           = @"image";
NSString * const NewsTagSummary         = @"description";
NSString * const NewsTagPostDate        = @"pubDate";
NSString * const NewsTagHasBody         = @"hasBody";
NSString * const NewsTagBody            = @"body";


static NSString * const FeedListModifiedDateKey = @"feedListModifiedDateArray";

@implementation NewsDataController

@synthesize currentCategory, moduleTag, delegate, searchDelegate,
currentCategories = _currentCategories, currentStories = _currentStories;
@synthesize storiesRequest;
@synthesize searchRequests;

- (BOOL)requiresKurogoServer
{
    return NO;
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
        NSLog(@"Warning: NewsDataController moduleTag not set, cannot save preferences");
    }
    [[NSUserDefaults standardUserDefaults] setObject:mutableModDates forKey:FeedListModifiedDateKey];
}

- (void)dealloc
{
    self.currentCategories = nil;
    self.currentStories = nil;
    self.delegate = nil;
    self.searchDelegate = nil;
    self.moduleTag = nil;
    [self.storiesRequest cancel];
    self.storiesRequest = nil;
    for (KGORequest *aRequest in self.searchRequests) {
        [aRequest cancel];
    }
    self.searchRequests = nil;

    [_searchResults release];
    
    [super dealloc];
}

#pragma mark categories

- (NSArray *)latestCategories
{
    if (!_currentCategories) {    
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isMainCategory = YES AND moduleTag = %@", self.moduleTag];
        NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey:@"sortOrder" ascending:YES] autorelease];
        NSSortDescriptor *catSort = [[[NSSortDescriptor alloc] initWithKey:@"category_id" ascending:YES] autorelease]; // compat
        NSArray *results = [[CoreDataManager sharedManager] objectsForEntity:NewsCategoryEntityName
                                                           matchingPredicate:predicate
                                                             sortDescriptors:[NSArray arrayWithObjects:sort, catSort, nil]];
        if (results.count) {
            self.currentCategories = results;
        }
    }

    return _currentCategories;
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
    
    if (!results.count || !lastUpdate || [lastUpdate timeIntervalSinceNow] + NEWS_CATEGORY_EXPIRES_TIME < 0) {
        [self requestCategoriesFromServer];
    }
}

- (NewsCategory *)categoryWithId:(NSString *)categoryId {
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

- (NSArray *)searchableCategories
{
    return self.currentCategories;
}

#pragma mark stories

- (BOOL)canLoadMoreStories
{
    if ([self.currentCategory.moreStories intValue] > 0)
        return YES;
    
    return NO;
}

- (NSArray *)bookmarkedStories
{
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"bookmarked == YES AND ANY categories.moduleTag = %@", self.moduleTag];
    return [[CoreDataManager sharedManager] objectsForEntity:NewsStoryEntityName matchingPredicate:pred];
}

- (void)fetchBookmarks
{
    NSArray *bookmarks = [self bookmarkedStories];
    
    if ([self.delegate respondsToSelector:@selector(dataController:didRetrieveStories:)]) {
        [self.delegate dataController:self didRetrieveStories:bookmarks];
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
        self.currentCategory = (NewsCategory *)[context objectWithID:[self.currentCategory objectID]];
    }
    [[[CoreDataManager sharedManager] managedObjectContext] refreshObject:self.currentCategory mergeChanges:NO];
    
    if (!self.currentCategory.lastUpdated
        || -[self.currentCategory.lastUpdated timeIntervalSinceNow] > NEWS_CATEGORY_EXPIRES_TIME
        // TODO: make sure the following doesn't result an infinite loop if stories legitimately don't exist
        || !self.currentCategory.stories.count)
    {
        DLog(@"last updated: %@", self.currentCategory.lastUpdated);
        [self requestStoriesForCategory:categoryId afterId:nil];
        return;
    }
    
    NSSortDescriptor *dateSort = [[[NSSortDescriptor alloc] initWithKey:@"sortOrder" ascending:YES] autorelease];
    //NSSortDescriptor *idSort = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:NO] autorelease];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:dateSort, //idSort,
                                nil];
    
    NSArray *results = [self.currentCategory.stories sortedArrayUsingDescriptors:sortDescriptors];
    
    if ([self.delegate respondsToSelector:@selector(dataController:didRetrieveStories:)]) {
        [self.delegate dataController:self didRetrieveStories:results];
    }
}

- (void)pruneStoriesForCategoryId:(NSString *)categoryId
{
    NewsCategory *category = nil;
    NSArray *stories = nil;
    
    if (categoryId) {
        category = [self categoryWithId:categoryId];
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"bookmarked != YES"];
        stories = [[category.stories filteredSetUsingPredicate:pred] allObjects];
        
    } else if (!categoryId) {
        NSPredicate *pred = [NSPredicate predicateWithFormat:
                             @"bookmarked != YES AND ANY categories.moduleTag = %@", self.moduleTag];
        stories = [[CoreDataManager sharedManager] objectsForEntity:NewsStoryEntityName
                                                  matchingPredicate:pred];
    }
    
    [[CoreDataManager sharedManager] deleteObjects:stories];
    
    if (category) {
        category.stories = nil;
    }
    [[CoreDataManager sharedManager] saveData];
    
    if ([self.delegate respondsToSelector:@selector(dataController:didPruneStoriesForCategoryId:)]) {
        [self.delegate dataController:self didPruneStoriesForCategoryId:categoryId];
    }
}

/*
- (void)readFeedData:(NSDictionary *)feedData
{
}

- (void)fetchSearchResultsFromStore
{
    
}
*/

- (void)requestCategoriesFromServer {
    KGORequest *request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                          module:self.moduleTag
                                                                            path:@"categories"
                                                                         version:1
                                                                          params:nil];
    
    NSDate *date = self.feedListModifiedDate;
    if (date) {
        request.ifModifiedSince = date;
    }
    
    __block NewsDataController *blockSelf = self;
    __block NSArray *oldCategories = self.currentCategories;
    
    [request connectWithResponseType:[NSArray class] callback:^(id result) {
        
        int retVal = REQUEST_CATEGORIES_UNCHANGED;
        
        NSArray *newCategoryDicts = (NSArray *)result;
        
        NSArray *newCategoryIds = [newCategoryDicts mappedArrayUsingBlock:^id(id element) {
            return [(NSDictionary *)element nonemptyStringForKey:@"id"];
        }];
        
        for (NewsCategory *oldCategory in oldCategories) {
            if (![newCategoryIds containsObject:oldCategory.category_id]) {
                [[CoreDataManager sharedManager] deleteObject:oldCategory];
                retVal = REQUEST_CATEGORIES_CHANGED;
            }
        }
        
        for (NSInteger i = 0; i < newCategoryDicts.count; i++) {
            NSDictionary *categoryDict = [newCategoryDicts dictionaryAtIndex:i];
            NSString *categoryId = [categoryDict nonemptyStringForKey:@"id"];
            NewsCategory *category = [blockSelf categoryWithId:categoryId];
            if (!category) {
                retVal = REQUEST_CATEGORIES_CHANGED;
                category = [blockSelf categoryWithDictionary:categoryDict];
            }
            if (!category.sortOrder || ![category.sortOrder isEqualToNumber:[NSNumber numberWithInt: i]]) {
                category.sortOrder = [NSNumber numberWithInt: i];
                retVal = REQUEST_CATEGORIES_CHANGED;
            }
        }
        
        [[CoreDataManager sharedManager] saveDataWithTemporaryMergePolicy:NSOverwriteMergePolicy];
        
        blockSelf.feedListModifiedDate = [NSDate date];
        
        return retVal;
    }];
}

- (NewsCategory *)categoryWithDictionary:(NSDictionary *)categoryDict
{
    NewsCategory *category = nil;
    NSString *categoryId = [categoryDict nonemptyStringForKey:@"id"];
    if (categoryId) {
        category = [self categoryWithId:categoryId];
        if (!category) {
            category = [[CoreDataManager sharedManager] insertNewObjectForEntityForName:NewsCategoryEntityName];
            category.moduleTag = self.moduleTag;
            category.category_id = categoryId;
        }
        category.title = [categoryDict nonemptyStringForKey:@"title"];
        category.isMainCategory = [NSNumber numberWithBool:YES];
        category.moreStories = [NSNumber numberWithInt:LOADMORE_LIMIT];
        category.nextSeekId = [NSNumber numberWithInt:0];
    }
    return category;
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
        NewsStory *story = [[self.currentStories filteredArrayUsingPredicate:pred] lastObject];
        if (story) {
            NSInteger index = [self.currentStories indexOfObject:story];
            if (index != NSNotFound) {
                start = index+1;
            }
        }
    }
    
    NSInteger moreStories = [self.currentCategory.moreStories integerValue];
    NSInteger limit = (moreStories && moreStories < LOADMORE_LIMIT) ? moreStories : LOADMORE_LIMIT;
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSString stringWithFormat:@"%d", start], @"start",
                            [NSString stringWithFormat:@"%d", limit], @"limit",
                            categoryId, @"categoryID", 
                            @"full", @"mode", nil];
    
    KGORequest *request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                          module:self.moduleTag
                                                                            path:@"stories"
                                                                         version:1
                                                                          params:params];
    self.storiesRequest = request;
    
    __block NewsDataController *blockSelf = self;
    __block NewsCategory *category = self.currentCategory;
    [request connectWithCallback:^(id result) {
        NSDictionary *resultDict = (NSDictionary *)result;
        NSArray *stories = [resultDict arrayForKey:@"stories"];
        // need to bring category to local context
        // http://stackoverflow.com/questions/1554623/illegal-attempt-to-establish-a-relationship-xyz-between-objects-in-different-co
        NewsCategory *mergedCategory = nil;
        
        NSInteger sortOrder = start;
        for (NSDictionary *storyDict in stories) {
            NewsStory *story = [blockSelf storyWithDictionary:storyDict];
            story.sortOrder = [NSNumber numberWithInt:sortOrder];
            sortOrder++;
            NSMutableSet *mutableCategories = [story mutableSetValueForKey:@"categories"];
            if (!mergedCategory) {
                mergedCategory = (NewsCategory *)[[story managedObjectContext] objectWithID:[category objectID]];
            }
            if (mergedCategory) {
                [mutableCategories addObject:mergedCategory];
            }
            story.categories = mutableCategories;
        }
        
        mergedCategory.moreStories = [resultDict numberForKey:@"moreStories"];
        mergedCategory.lastUpdated = [NSDate date];
        [[CoreDataManager sharedManager] saveData];
        
        return (NSInteger)[stories count];
    }];
}

- (NewsStory *)storyWithDictionary:(NSDictionary *)storyDict {
    // use existing story if it's already in the db
    NSString *GUID = [storyDict nonemptyStringForKey:NewsTagStoryId];
    NewsStory *story = [[CoreDataManager sharedManager] uniqueObjectForEntity:NewsStoryEntityName 
                                                                    attribute:@"identifier" 
                                                                        value:GUID];
    // otherwise create new
    if (!story) {
        story = (NewsStory *)[[CoreDataManager sharedManager] insertNewObjectForEntityForName:NewsStoryEntityName];
        story.identifier = GUID;
    }
    
    story.moduleTag = self.moduleTag;
    
    double unixtime = [[storyDict objectForKey:@"pubDate"] doubleValue];
    NSDate *postDate = [NSDate dateWithTimeIntervalSince1970:unixtime];
    
    story.postDate = postDate;
    story.title = [storyDict nonemptyStringForKey:NewsTagTitle];
    story.link = [storyDict nonemptyStringForKey:NewsTagLink];
    story.author = [storyDict nonemptyStringForKey:NewsTagAuthor];
    story.summary = [storyDict nonemptyStringForKey:NewsTagSummary];
    story.hasBody = [NSNumber numberWithBool:[storyDict boolForKey:NewsTagHasBody]];
    story.body = [storyDict nonemptyStringForKey:NewsTagBody];
    
    NSDictionary *imageDict = [storyDict dictionaryForKey:NewsTagImage];
    if (imageDict) {
        // an old thumb may already exist
        // in which case do not create a new one
        if (!story.thumbImage) {
            story.thumbImage = [[CoreDataManager sharedManager] insertNewObjectForEntityForName:NewsImageEntityName];
        }
        story.thumbImage.url = [imageDict nonemptyStringForKey:@"src"];
        story.thumbImage.thumbParent = story;
    } else {
        story.thumbImage = nil;
    }
    return story;
}

#pragma mark Search

- (void)searchStories:(NSString *)searchTerms
{
    // cancel any previous search requests
    for (KGORequest *request in self.searchRequests) {
        [request cancel];
    }
    
    if (!_searchResults) {
        _searchResults = [[NSMutableArray alloc] init];
    } else {
        for (NewsStory *aStory in _searchResults) {
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
    
    for (NewsCategory *category in [self searchableCategories]) {
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                category.category_id, @"categoryID",
                                searchTerms, @"q", nil];
        
        KGORequest *request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                              module:self.moduleTag
                                                                                path:@"search"
                                                                             version:1
                                                                              params:params];
        request.expectedResponseType = [NSArray class];
        
        [self.searchRequests addObject:request];
        [request connect];
    }
}
/*
- (NSArray *)latestSearchResults
{
    NSPredicate *predicate = nil;
    NSSortDescriptor *relevanceSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"searchResult" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:relevanceSortDescriptor];
    [relevanceSortDescriptor release];
    
    predicate = [NSPredicate predicateWithFormat:@"searchResult > 0"];
    
    // show everything that comes back
    NSArray *results = [[CoreDataManager sharedManager] objectsForEntity:NewsStoryEntityName
                                                       matchingPredicate:predicate
                                                         sortDescriptors:sortDescriptors];
    return results;
}

- (void)fetchSearchResultsFromStore
{
    NSArray *results = [self latestSearchResults];
    if (results && [self.delegate respondsToSelector:@selector(dataController:didRetrieveStories:)]) {
        [self.delegate dataController:self didRetrieveStories:results];
    }
}
*/
#pragma mark KGORequestDelegate

- (void)request:(KGORequest *)request didReceiveResult:(id)result
{
    if ([self.searchRequests containsObject:request]) {
        for (NSDictionary *storyDict in (NSArray *)result) {
            NewsStory *story = [self storyWithDictionary:storyDict]; 
            story.searchResult = [NSNumber numberWithInt:1];
            if([_searchResults indexOfObject:story] == NSNotFound) {
                [_searchResults addObject:story];
            }
        }
    }
}

- (void)request:(KGORequest *)request didHandleResult:(NSInteger)returnValue {
    NSString *path = request.path;
    
    if (request == self.storiesRequest) {
        NSString *categoryId = [request.getParams objectForKey:@"categoryID"];
        NSString *startId = [request.getParams objectForKey:@"start"];
        [self fetchStoriesForCategory:categoryId startId:startId];
        
    } else if ([path isEqualToString:@"categories"]) {    
        switch (returnValue) {
            case REQUEST_CATEGORIES_CHANGED:
            {
                self.currentCategories = nil;
                [self fetchCategories];
                break;
            }
            default:
                break;
        }
    }
}

- (void)request:(KGORequest *)request didMakeProgress:(CGFloat)progress {
    if (request == self.storiesRequest) {
        //NSString *categoryID = [request.getParams objectForKey:@"categoryID"];
        
        // TODO: see if progress value needs tweaking
        
        if ([self.delegate respondsToSelector:@selector(dataController:didMakeProgress:)]) {
            [self.delegate dataController:self didMakeProgress:progress];
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

- (void)requestResponseUnchanged:(KGORequest *)request
{
    [request cancel];
    
    NSDate *date = [self feedListModifiedDate];
    if (!date || [date timeIntervalSinceNow] + NEWS_CATEGORY_EXPIRES_TIME < 0) {
        self.feedListModifiedDate = [NSDate date];
    }
    
    [self fetchCategories];
}

- (void)requestWillTerminate:(KGORequest *)request {
    if (request == self.storiesRequest) {
        self.storiesRequest = nil;
        
    } else if ([self.searchRequests containsObject:request]) {
        [self.searchRequests removeObject:request];
        
        if (self.searchRequests.count == 0) { // all searches have completed
            if (_searchResults) {
                if ([self.delegate respondsToSelector:@selector(dataController:didReceiveSearchResults:)]) {
                    [self.delegate dataController:self didReceiveSearchResults:_searchResults];
                }

                // TODO: use a user-facing string instead of module tag
                [self.searchDelegate receivedSearchResults:_searchResults forSource:self.moduleTag];
                
                [_searchResults release];
                _searchResults = nil;
            }
        }
    }
}

@end


