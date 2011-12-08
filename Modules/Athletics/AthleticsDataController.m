//
//  AthleticsDataController.m
//  Universitas
//
//  Created by Liu Mingxing on 12/2/11.
//  Copyright (c) 2011 Symbio Inc. All rights reserved.
//
#import "Foundation+KGOAdditions.h"
#import "AthleticsDataController.h"
#import "CoreDataManager.h"
#import "AthleticsModel.h"
#import "KGORequest.h"

#define REQUEST_CATEGORIES_CHANGED 1
#define REQUEST_CATEGORIES_UNCHANGED 2
#define LOADMORE_LIMIT 10

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
@synthesize currentStories;
@synthesize currentCategories;
@synthesize currentCategory;
@synthesize storiesRequest;

- (BOOL)requiresKurogoServer {
    return YES;
}

#pragma mark - KGORequestDelegate
- (void)requestWillTerminate:(KGORequest *)request {
    
}

- (void)request:(KGORequest *)request didFailWithError:(NSError *)error {
    
}

- (void)request:(KGORequest *)request didHandleResult:(NSInteger)returnValue {
    
}

- (void)request:(KGORequest *)request didReceiveResult:(id)result {
    
}

- (void)request:(KGORequest *)request didMakeProgress:(CGFloat)progress {
    
}

- (void)requestDidReceiveResponse:(KGORequest *)request {
    
}

- (void)requestResponseUnchanged:(KGORequest *)request {
    
}

- (NSArray *)bookmarkedStories
{
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"bookmarked == YES AND ANY categories.moduleTag = %@", self.moduleTag];
    return [[CoreDataManager sharedManager] objectsForEntity:AthleticsStoryEntityName matchingPredicate:pred];
}


#pragma mark - Serach

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
        [self requestCategoriesFromServer];
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
        || [self.currentCategory.lastUpdated timeIntervalSinceNow] > ATHLETICS_CATEGORY_EXPIRES_TIME
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

- (void)requestCategoriesFromServer {
    KGORequest *request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                          module:self.moduleTag
                                                                            path:@"news?sport=SPORT"
                                                                         version:1
                                                                          params:nil];
    
    NSDate *date = self.feedListModifiedDate;
    if (date) {
        request.ifModifiedSince = date;
    }
    
    __block AthleticsDataController *blockSelf = self;
    __block NSArray *oldCategories = self.currentCategories;
    
    [request connectWithResponseType:[NSArray class] callback:^(id result) {
        
        int retVal = REQUEST_CATEGORIES_UNCHANGED;
        
        NSArray *newCategoryDicts = (NSArray *)result;
        
        NSArray *newCategoryIds = [newCategoryDicts mappedArrayUsingBlock:^id(id element) {
            return [(NSDictionary *)element nonemptyStringForKey:@"id"];
        }];
        
        for (AthleticsCategory *oldCategory in oldCategories) {
            if (![newCategoryIds containsObject:oldCategory.category_id]) {
                [[CoreDataManager sharedManager] deleteObject:oldCategory];
                retVal = REQUEST_CATEGORIES_CHANGED;
            }
        }
        
        for (NSInteger i = 0; i < newCategoryDicts.count; i++) {
            NSDictionary *categoryDict = [newCategoryDicts dictionaryAtIndex:i];
            NSString *categoryId = [categoryDict nonemptyStringForKey:@"id"];
            AthleticsCategory *category = [blockSelf categoryWithId:categoryId];
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
        category.isMainCategory = [NSNumber numberWithBool:YES];
        category.moreStories = [NSNumber numberWithInt:-1];
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
        AthleticsStory *story = [[self.currentStories filteredArrayUsingPredicate:pred] lastObject];
        if (story) {
            NSInteger index = [self.currentStories indexOfObject:story];
            if (index != NSNotFound) {
                start = index;
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
    
    __block AthleticsDataController *blockSelf = self;
    __block AthleticsCategory *category = self.currentCategory;
    [request connectWithCallback:^(id result) {
        NSDictionary *resultDict = (NSDictionary *)result;
        NSArray *stories = [resultDict arrayForKey:@"stories"];
        // need to bring category to local context
        // http://stackoverflow.com/questions/1554623/illegal-attempt-to-establish-a-relationship-xyz-between-objects-in-different-co
        AthleticsCategory *mergedCategory = nil;
        
        for (NSDictionary *storyDict in stories) {
            AthleticsStory *story = [blockSelf storyWithDictionary:storyDict];
            NSMutableSet *mutableCategories = [story mutableSetValueForKey:@"categories"];
            if (!mergedCategory) {
                mergedCategory = (AthleticsCategory *)[[story managedObjectContext] objectWithID:[category objectID]];
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

- (AthleticsStory *)storyWithDictionary:(NSDictionary *)storyDict {
    // use existing story if it's already in the db
    NSString *GUID = [storyDict nonemptyStringForKey:AthleticsTagStoryId];
    AthleticsStory *story = [[CoreDataManager sharedManager] uniqueObjectForEntity:AthleticsStoryEntityName 
                                                                    attribute:@"identifier" 
                                                                        value:GUID];
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



- (void)dealloc {
    self.moduleTag = nil;

    [super dealloc];
}
@end
