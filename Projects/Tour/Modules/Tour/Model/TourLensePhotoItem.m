#import "TourLensePhotoItem.h"
#import "TourMediaItem.h"
#import "TourConstants.h"
#import "Foundation+KGOAdditions.h"
#import "CoreDataManager.h"

@implementation TourLensePhotoItem
@dynamic title;
@dynamic photo;


+ (TourLensePhotoItem *)itemWithDictionary:(NSDictionary *)itemDict {
    TourLensePhotoItem *item = [[CoreDataManager sharedManager] 
                                insertNewObjectForEntityForName:TourLensePhotoItemEntityName];
    item.title = [itemDict stringForKey:@"title" nilIfEmpty:NO];
    item.photo = [TourMediaItem mediaItemForURL:[itemDict stringForKey:@"url" nilIfEmpty:NO]];
    return item;
}

@end
