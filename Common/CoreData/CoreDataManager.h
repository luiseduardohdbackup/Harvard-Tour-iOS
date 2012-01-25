#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface CoreDataManager : NSObject {
	NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
}

@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, readonly) NSString *applicationCachesDirectory;

- (NSManagedObjectModel *)managedObjectModel;

+ (CoreDataManager *)sharedManager;

- (void)mergeChanges:(NSNotification *)aNotification;
- (void)observeSaveForContext:(NSManagedObjectContext *)aContext;

- (NSArray *)fetchDataForAttribute:(NSString *)attributeName;
- (NSArray *)fetchDataForAttribute:(NSString *)attributeName sortDescriptor:(NSSortDescriptor *)sortDescriptor;
- (void)clearDataForAttribute:(NSString *)attributeName;

- (id)insertNewObjectForEntityForName:(NSString *)entityName;
- (id)insertNewObjectWithNoContextForEntity:(NSString *)entityName;
- (id)objectsForEntity:(NSString *)entityName matchingPredicate:(NSPredicate *)predicate sortDescriptors:(NSArray *)sortDescriptors;
- (id)objectsForEntity:(NSString *)entityName matchingPredicate:(NSPredicate *)predicate;
- (id)uniqueObjectForEntity:(NSString *)entityName attribute:(NSString *)attributeName value:(id)value;

- (void)deleteObjects:(NSArray *)objects;
- (void)deleteObject:(NSManagedObject *)object;
- (void)saveData;
- (void)saveDataWithTemporaryMergePolicy:(id)temporaryMergePolicy;

// migration
- (NSString *)storeFileName;
- (NSString *)currentStoreFileName;
- (BOOL)migrateData;
- (BOOL)deleteStore;

@end
