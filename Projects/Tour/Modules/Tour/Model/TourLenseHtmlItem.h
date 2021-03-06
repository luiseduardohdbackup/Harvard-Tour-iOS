
/****************************************************************
 *
 *  Copyright 2011 The President and Fellows of Harvard College
 *  Copyright 2011 Modo Labs Inc.
 *
 *****************************************************************/

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "TourLenseItem.h"


@interface TourLenseHtmlItem : TourLenseItem {
@private
}
@property (nonatomic, retain) NSString * html;
+ (TourLenseHtmlItem *)itemWithDictionary:(NSDictionary *)itemDict;

@end
