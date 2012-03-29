#import "PersonAddress.h"
#import "KGOPerson.h"

NSString * const PersonAddressEntityName = @"PersonAddress";

@implementation PersonAddress 

@dynamic person;

- (NSDictionary *)dictionary {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            self.label, @"label",
            [self dictionaryWithValuesForKeys:
             [NSArray arrayWithObjects:
              @"city",
              @"country",
              @"zip",
              @"state",
              @"street",
              @"street2",
              @"label",
              @"display",
              nil]], @"value",
            nil];
}

@end
