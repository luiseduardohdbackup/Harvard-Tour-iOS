#import "CalendarDataManager.h"
#import "CoreDataManager.h"
#import "Foundation+KGOAdditions.h"
#import "CalendarModel.h"
#import <EventKit/EventKit.h>

#define EVENT_TIMEOUT -300

#define CALENDAR_GROUP_EXPIRE_TIME 900
#define CALENDAR_LIST_EXPIRE_TIME 900

@implementation CalendarDataManager

@synthesize delegate, moduleTag;

- (id)init
{
    self = [super init];
    if (self) {
        NSDateFormatter *mediumDayDF = [[[NSDateFormatter alloc] init] autorelease];
        [mediumDayDF setDateStyle:NSDateFormatterMediumStyle];
        [mediumDayDF setTimeStyle:NSDateFormatterNoStyle];
        NSDateFormatter *shortDayDF = [[[NSDateFormatter alloc] init] autorelease];
        [shortDayDF setDateStyle:NSDateFormatterShortStyle];
        [shortDayDF setTimeStyle:NSDateFormatterNoStyle];
        NSDateFormatter *shortTimeDF = [[[NSDateFormatter alloc] init] autorelease];
        [shortTimeDF setDateStyle:NSDateFormatterNoStyle];
        [shortTimeDF setTimeStyle:NSDateFormatterShortStyle];
        NSDateFormatter *dateTimeDF = [[[NSDateFormatter alloc] init] autorelease];
        [dateTimeDF setDateStyle:NSDateFormatterShortStyle];
        [dateTimeDF setTimeStyle:NSDateFormatterShortStyle];
        
        _dateFormatters = [[NSDictionary alloc] initWithObjectsAndKeys:
                           mediumDayDF, @"mediumDay",
                           shortDayDF, @"shortDay",
                           shortTimeDF, @"shortTime",
                           dateTimeDF, @"dateTime",
                           nil];

        _categoriesRequests = [[NSMutableDictionary alloc] init];
        _eventsRequests = [[NSMutableDictionary alloc] init];
        _detailRequests = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSString *)mediumDateStringFromDate:(NSDate *)date
{
    return [[_dateFormatters objectForKey:@"mediumDay"] stringFromDate:date];
}

- (NSString *)shortDateStringFromDate:(NSDate *)date
{
    return [[_dateFormatters objectForKey:@"shortDay"] stringFromDate:date];
}

- (NSString *)shortTimeStringFromDate:(NSDate *)date
{
    return [[_dateFormatters objectForKey:@"shortTime"] stringFromDate:date];
}

- (NSString *)shortDateTimeStringFromDate:(NSDate *)date
{
    return [[_dateFormatters objectForKey:@"dateTime"] stringFromDate:date];
}

- (NSString *)dateTimeStringForEvent:(KGOEvent *)event multiline:(BOOL)multiline
{
    NSString *timeString = nil;

    NSString *startDateString = [self mediumDateStringFromDate:event.startDate];

    if ([event.allDay boolValue]) {
        NSString *endDateString = [self mediumDateStringFromDate:event.endDate];
        if ([endDateString isEqualToString:startDateString]) {
            timeString = [NSString stringWithFormat:@"%@\n%@",
                          startDateString,
                          NSLocalizedString(@"CALENDAR_ALL_DAY_SUBTITLE", @"All day")];
        } else {
            timeString = [NSString stringWithFormat:@"%@ - %@", startDateString, endDateString];
            
        }

    } else {
        NSString *startTimeString = [self shortTimeStringFromDate:event.startDate];

        if (event.endDate) {
            NSString *endDateString = [self mediumDateStringFromDate:event.endDate];
            NSString *endTimeString = [self shortTimeStringFromDate:event.endDate];
            
            if (multiline) {
                NSString *dateString = startDateString;
                if (![endDateString isEqualToString:dateString]) {
                    dateString = [NSString stringWithFormat:@"%@ - %@", dateString, endDateString];
                }
                
                timeString = [NSString stringWithFormat:@"%@\n%@-%@",
                              dateString, startTimeString, endTimeString];
            } else {
                if ([endDateString isEqualToString:startDateString]) {
                    timeString = [NSString stringWithFormat:@"%@ %@-%@",
                                  startDateString, startTimeString, endTimeString];
                } else {
                    timeString = [NSString stringWithFormat:@"%@ %@ - %@ %@",
                                  startDateString, startTimeString, endDateString, endTimeString];
                }
            }

        } else {
            if (multiline) {
                timeString = [NSString stringWithFormat:@"%@\n%@", startDateString, startTimeString];
            } else {
                timeString = [NSString stringWithFormat:@"%@ %@", startDateString, startTimeString];
            }
        }
    }
    return timeString;
}

- (EKEventStore *)eventStore
{
    if (!_eventStore) {
        _eventStore = [[EKEventStore alloc] init];
    }
    return _eventStore;
}

- (KGOCalendarGroup *)currentGroup
{
    return _currentGroup;
}

- (void)selectGroupAtIndex:(NSInteger)index
{
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"sortOrder = %d", index];
    KGOCalendarGroup *group = [[[CoreDataManager sharedManager] objectsForEntity:KGOEntityNameCalendarGroup
                                                               matchingPredicate:pred] lastObject];
    if (group) {
        [_currentGroup release];
        _currentGroup = [group retain];
    }
}

- (BOOL)requestGroups
{
    BOOL success = NO;
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"sortOrder" ascending:YES];
    NSArray *oldGroups = [[CoreDataManager sharedManager] objectsForEntity:KGOEntityNameCalendarGroup
                                                         matchingPredicate:nil
                                                           sortDescriptors:[NSArray arrayWithObject:sort]];
    
    if (oldGroups) {
        success = YES;
        if ([self.delegate respondsToSelector:@selector(groupsDidChange:)]) {
            [self.delegate groupsDidChange:oldGroups];
        }
    }
    
    if ([[KGORequestManager sharedManager] isReachable]) {
        if (_groupsRequest) {
            return success;
        }
        
        _groupsRequest = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                         module:self.moduleTag
                                                                           path:@"groups"
                                                                        version:2
                                                                         params:nil];
        if (oldGroups) {
            _groupsRequest.minimumDuration = CALENDAR_GROUP_EXPIRE_TIME;
        }
        _groupsRequest.expectedResponseType = [NSArray class];
        success = [_groupsRequest connect];
    }
    return success;
}

- (BOOL)requestCalendarsForGroup:(KGOCalendarGroup *)group
{
    BOOL success = NO;
    if (group.calendars.count) {
        success = YES;
        if ([self.delegate respondsToSelector:@selector(groupDataDidChange:)]) {
            [self.delegate groupDataDidChange:group];
        }
    }
        
    if ([[KGORequestManager sharedManager] isReachable]) {
        KGORequest *request = [_categoriesRequests objectForKey:group.identifier];
        if (request) {
            return success;
        }
        
        NSDictionary *params = [NSDictionary dictionaryWithObject:group.identifier forKey:@"group"];
        request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                  module:self.moduleTag
                                                                    path:@"calendars"
                                                                 version:2
                                                                  params:params];
        
        [_categoriesRequests setObject:request forKey:group.identifier];
        request.expectedResponseType = [NSArray class];
        request.minimumDuration = CALENDAR_LIST_EXPIRE_TIME;
        success = [request connect];
    }
    return success;
}

NSDate *dateForMidnightFromInterval(NSTimeInterval interval)
{
    NSDate *result = nil;
    if (interval) {
        NSDate *time = [NSDate dateWithTimeIntervalSince1970:interval];
        if (time) {
            NSUInteger flags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
            NSDateComponents *comps = [[NSCalendar currentCalendar] components:flags fromDate:time];
            result = [[NSCalendar currentCalendar] dateFromComponents:comps];
        }
    }
    return result;
}

- (BOOL)requestEventsForCalendar:(KGOCalendar *)calendar params:(NSDictionary *)params
{
    BOOL success = NO;
    NSArray *events = [calendar.events allObjects];
    if (events.count) {
        NSArray *oldEvents = [events filteredArrayUsingPredicate:
                              [NSPredicate predicateWithFormat:
                               @"lastUpdate < %@",
                               [NSDate dateWithTimeIntervalSinceNow:EVENT_TIMEOUT]]];
        
        if (oldEvents.count) {
            [[CoreDataManager sharedManager] deleteObjects:oldEvents];
            
        } else {
            
            NSMutableArray *predTemplates = [NSMutableArray array];
            NSMutableArray *predArguments = [NSMutableArray array];
            
            NSDate *start = nil;
            NSString *startString = [params objectForKey:@"start"];
            if (startString) {
                start = [NSDate dateWithTimeIntervalSince1970:[startString doubleValue]];
            } else {
                NSTimeInterval interval = [[params objectForKey:@"time"] doubleValue];
                start = dateForMidnightFromInterval(interval);
            }
            
            if (start) {
                [predTemplates addObject:@"startDate >= %@"];
                [predArguments addObject:start];
            }
            
            NSInteger limit = [[params objectForKey:@"limit"] integerValue];
            if (limit <= 0) {
                NSDate *end = nil;
                NSString *endString = [params objectForKey:@"endDate"];
                if (endString) {
                    end = [NSDate dateWithTimeIntervalSince1970:[endString doubleValue]];
                } else {
                    NSTimeInterval interval = [[params objectForKey:@"time"] doubleValue] + 24*60*60; // add 24 hrs
                    end = dateForMidnightFromInterval(interval);
                }
                if (end) {
                    [predTemplates addObject:@"endDate < %@"];
                    [predArguments addObject:end];
                }
            }
            
            NSArray *filteredEvents = nil;
            NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"startDate"
                                                                                              ascending:YES]];
            if (predTemplates.count) {
                NSPredicate *pred = [NSPredicate predicateWithFormat:[predTemplates componentsJoinedByString:@" AND "]
                                                       argumentArray:predArguments];
                
                filteredEvents = [[events filteredArrayUsingPredicate:pred] sortedArrayUsingDescriptors:sortDescriptors];
            } else {
                filteredEvents = [events sortedArrayUsingDescriptors:sortDescriptors];
            }
            
            if (filteredEvents.count >= limit) { // limit is 0 if unspecified
                filteredEvents = [filteredEvents subarrayWithRange:NSMakeRange(0, limit)];
                for (KGOEvent *event in filteredEvents) {
                    event.dataManager = self;
                }
                
                if ([self.delegate respondsToSelector:@selector(eventsDidChange:calendar:didReceiveResult:)]) {
                    [self.delegate eventsDidChange:filteredEvents calendar:calendar didReceiveResult:NO];
                }
                
                if (filteredEvents.count) {
                    return YES;
                }
            }
        }
    }
    
    if ([[KGORequestManager sharedManager] isReachable]) {
        NSString *requestIdentifier = calendar.identifier;
        KGORequest *request = [_eventsRequests objectForKey:requestIdentifier];
        if (request) {
            [request cancel];
            [_eventsRequests removeObjectForKey:requestIdentifier];
        }
        
        request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                                  module:self.moduleTag
                                                                    path:@"events"
                                                                 version:2
                                                                  params:params];
        request.expectedResponseType = [NSDictionary class];
        [_eventsRequests setObject:request forKey:requestIdentifier];
        [request connect];
        
        if (request) {
            success = YES;
        }
    }
    
    return success;
}

- (BOOL)requestEventsForCalendar:(KGOCalendar *)calendar time:(NSDate *)time
{
    NSString *timeString = [NSString stringWithFormat:@"%.0f", [time timeIntervalSince1970]];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            calendar.identifier, @"calendar",
                            calendar.type, @"type",
                            timeString, @"time",
                            nil];
    return [self requestEventsForCalendar:calendar params:params];
}

- (BOOL)requestEventsForCalendar:(KGOCalendar *)calendar start:(NSDate *)start limit:(NSInteger)limit
{
    NSString *startString = [NSString stringWithFormat:@"%.0f", [start timeIntervalSince1970]];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            calendar.identifier, @"calendar",
                            calendar.type, @"type",
                            startString, @"start",
                            [NSString stringWithFormat:@"%d", limit], @"limit",
                            nil];
    return [self requestEventsForCalendar:calendar params:params];
}

- (BOOL)requestEventsForCalendar:(KGOCalendar *)calendar startDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   calendar.identifier, @"calendar",
                                   calendar.type, @"type",
                                   nil];
    
    if (startDate) {
        NSString *startString = [NSString stringWithFormat:@"%.0f", [startDate timeIntervalSince1970]];
        [params setObject:startString forKey:@"start"];
    }
    
    if (endDate) {
        NSString *endString = [NSString stringWithFormat:@"%.0f", [endDate timeIntervalSince1970]];
        [params setObject:endString forKey:@"end"];
    }
    
    return [self requestEventsForCalendar:calendar params:params];
}

- (BOOL)requestDetailsForEvent:(KGOEvent *)event
{
    if (!event.identifier.length) {
        return NO;
    }
    
    KGORequest *request = [_detailRequests objectForKey:event.identifier];
    if (request) {
        return NO;
    }
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            event.identifier, @"id",
                            [NSString stringWithFormat:@"%.0f", [event.startDate timeIntervalSince1970]], @"start",
                            nil];
    DLog(@"requesting event details %@", params);
    request = [[KGORequestManager sharedManager] requestWithDelegate:self
                                                              module:self.moduleTag
                                                                path:@"detail"
                                                             version:1
                                                              params:params];

    [_detailRequests setObject:request forKey:event.identifier];
    [_detailRequestEvents setObject:event forKey:event.identifier];
    return [request connect];
}

- (void)request:(KGORequest *)request didFailWithError:(NSError *)error
{
    DLog(@"request failed: %@", [error description]);
}

#pragma mark KGORequestDelegate


- (void)requestWillTerminate:(KGORequest *)request
{
    if (request == _groupsRequest) {
        _groupsRequest = nil;
        
    } else {
        NSString *category = [request.getParams objectForKey:@"calendar"];
        if (category) {
            [_eventsRequests removeObjectForKey:category];

        } else {
            NSString *group = [request.getParams objectForKey:@"group"];
            if (group) {
                [_categoriesRequests removeObjectForKey:group];
            }
        }
    }
}

/*
// TODO: let delegate know of failure so UI can be adjusted accordingly
- (void)request:(KGORequest *)request didFailWithError:(NSError *)error
{
    [[KGORequestManager sharedManager] showAlertForError:error];
}
*/
- (void)request:(KGORequest *)request didReceiveResult:(id)result
{
#pragma mark Request - groups
    if (request == _groupsRequest) {

        NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"sortOrder" ascending:YES];
        NSString *currentIdentifier = _currentGroup.identifier;
        NSArray *oldGroups = [[CoreDataManager sharedManager] objectsForEntity:KGOEntityNameCalendarGroup
                                                             matchingPredicate:nil
                                                               sortDescriptors:[NSArray arrayWithObject:sort]];
        
        id (^identifiersFromGroups)(id) = ^(id aGroup) {
            return (id)[aGroup identifier]; // compiler complains if it can tell this is a string
        };
        
        NSArray *oldGroupIDs = [oldGroups mappedArrayUsingBlock:identifiersFromGroups];

        NSArray *groups = (NSArray *)result;
        BOOL groupsDidChange = oldGroupIDs.count != groups.count;

        NSMutableArray *newGroups = [NSMutableArray array];
        for (NSInteger i = 0; i < groups.count; i++) {
            NSDictionary *aDict = [groups dictionaryAtIndex:i];
            KGOCalendarGroup *group = [KGOCalendarGroup groupWithDictionary:aDict];
            if (group) {
                if (!groupsDidChange && ![group.identifier isEqualToString:[oldGroupIDs objectAtIndex:i]]) {
                    groupsDidChange = YES;
                }
                if (groupsDidChange) {
                    group.sortOrder = [NSNumber numberWithInt:i];
                }
                [newGroups addObject:group];
            }
        }

        if (groupsDidChange) {
            NSArray *newGroupIDs = [newGroups mappedArrayUsingBlock:identifiersFromGroups];
            if (_currentGroup && ![newGroupIDs containsObject:currentIdentifier]) {
                [_currentGroup release];
                _currentGroup = [[newGroups objectAtIndex:0] retain];
            }
            for (KGOCalendarGroup *oldGroup in oldGroups) {
                if (![newGroupIDs containsObject:oldGroup.identifier]) {
                    [[CoreDataManager sharedManager] deleteObject:oldGroup];
                }
            }
            [[CoreDataManager sharedManager] saveData];
            if ([self.delegate respondsToSelector:@selector(groupsDidChange:)]) {
                [self.delegate groupsDidChange:newGroups];
            }
        }
#pragma mark Request - calendars
    } else if ([request.path isEqualToString:@"calendars"]) {
        
        NSString *groupID = [request.getParams objectForKey:@"group"];
        if ([self.currentGroup.identifier isEqualToString:groupID]) {
            NSArray *calendars = (NSArray *)result;
            if (calendars.count) {
                for (NSInteger i = 0; i < calendars.count; i++) {
                    NSDictionary *aDict = [calendars dictionaryAtIndex:i];
                    KGOCalendar *calendar = [KGOCalendar calendarWithDictionary:aDict];
                    if (calendar) {
                        calendar.sortOrder = [NSNumber numberWithInt:i];
                        [calendar addGroupsObject:self.currentGroup];
                    }
                }
                if ([self.delegate respondsToSelector:@selector(groupDataDidChange:)]) {
                    [self.delegate groupDataDidChange:self.currentGroup];
                }
            }
        }

#pragma mark Request - events
    } else if ([request.path isEqualToString:@"events"]) { // events
        
        NSString *calendarID = [request.getParams objectForKey:@"calendar"];
        KGOCalendar *calendar = [KGOCalendar calendarWithID:calendarID];

        // search results boilerplate
        NSInteger total = [result integerForKey:@"total"];
        NSInteger returned = [result integerForKey:@"returned"];
        if (total > returned) {
            // TODO: implement paging
        }
        
        //NSString *displayField = [result nonemptyStringForKey:@"displayField"];
        
        NSArray *eventDicts = [result arrayForKey:@"results"];
        if (returned > eventDicts.count)
            returned = eventDicts.count;
        
        NSMutableArray *array = [NSMutableArray array];
        for (NSInteger i = 0; i < returned; i++) {
            NSDictionary *aDict = [eventDicts objectAtIndex:i];
            KGOEvent *event = [KGOEvent eventWithDictionary:aDict module:self.moduleTag];
            event.dataManager = self;
            [event addCalendarsObject:calendar];
            [array addObject:event];
        }

        NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:YES]];
        
        [[CoreDataManager sharedManager] saveData];
        if ([self.delegate respondsToSelector:@selector(eventsDidChange:calendar:didReceiveResult:)]) {
            [self.delegate eventsDidChange:[array sortedArrayUsingDescriptors:sortDescriptors]
                                  calendar:calendar
                          didReceiveResult:YES];
        }
#pragma mark Request - detail
    } else if ([request.path isEqualToString:@"detail"]) {
        NSString *eventID = [result nonemptyForcedStringForKey:@"id"];
        KGOEvent *event = [_detailRequestEvents objectForKey:eventID];
        if (event) {
            [event updateWithDictionary:result];
            if ([self.delegate respondsToSelector:@selector(eventDetailsDidChange:)]) {
                [self.delegate eventDetailsDidChange:event];
            }
        }
    }
}

- (void)dealloc
{
    [_dateFormatters release];
    
    if (_groupsRequest) {
        [_groupsRequest cancel];
    }
    
    [_categoriesRequests enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [(KGORequest *)obj cancel];
    }];
    [_categoriesRequests release];
     
    [_eventsRequests enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [(KGORequest *)obj cancel];
    }];
    [_eventsRequests release];
    
    [_detailRequests enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [(KGORequest *)obj cancel];
    }];
    [_detailRequests release];
    
    [_currentGroup release];
    
    [_eventStore release];
    
    [super dealloc];
}

@end
