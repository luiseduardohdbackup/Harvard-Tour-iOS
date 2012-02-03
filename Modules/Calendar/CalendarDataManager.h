#import <Foundation/Foundation.h>
#import "CalendarModel.h"
#import "KGORequestManager.h"

@protocol CalendarDataManagerDelegate <NSObject>

- (void)groupsDidChange:(NSArray *)groups;
- (void)groupDataDidChange:(KGOCalendarGroup *)group;
- (void)eventsDidChange:(NSArray *)events
               calendar:(KGOCalendar *)calendar
       didReceiveResult:(BOOL)receivedResult; // didReceiveResult is a misnomer for "came from network"

@end

@class KGOCalendarGroup;

@interface CalendarDataManager : NSObject <KGORequestDelegate> {
    
    KGOCalendarGroup *_currentGroup;
    
    KGORequest *_groupsRequest;
    NSMutableDictionary *_categoriesRequests;
    NSMutableDictionary *_eventsRequests;
    
    NSDictionary *_dateFormatters;
    
}

@property (nonatomic, assign) id<CalendarDataManagerDelegate> delegate;
@property (nonatomic, readonly) KGOCalendarGroup *currentGroup;
@property (nonatomic, retain) ModuleTag *moduleTag;

- (BOOL)requestGroups;
- (BOOL)requestCalendarsForGroup:(KGOCalendarGroup *)group;

- (BOOL)requestEventsForCalendar:(KGOCalendar *)calendar params:(NSDictionary *)params;
- (BOOL)requestEventsForCalendar:(KGOCalendar *)calendar startDate:(NSDate *)startDate endDate:(NSDate *)endDate;
- (BOOL)requestEventsForCalendar:(KGOCalendar *)calendar time:(NSDate *)time;
- (BOOL)requestEventsForCalendar:(KGOCalendar *)calendar start:(NSDate *)start limit:(NSInteger)limit;

- (void)selectGroupAtIndex:(NSInteger)index;

- (NSString *)mediumDateStringFromDate:(NSDate *)date;
- (NSString *)shortDateStringFromDate:(NSDate *)date;
- (NSString *)shortTimeStringFromDate:(NSDate *)date;
- (NSString *)shortDateTimeStringFromDate:(NSDate *)date;

@end
