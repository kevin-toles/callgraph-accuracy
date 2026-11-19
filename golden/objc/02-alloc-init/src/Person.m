#import <Foundation/Foundation.h>

@interface Person : NSObject
- (instancetype)initWithName:(NSString *)name;
- (void)setup;
@end

@implementation Person
- (instancetype)initWithName:(NSString *)name {
  self = [super init];
  return self;
}
- (void)setup {
  Person *a = [[Person alloc] initWithName:@"a"];
  Person *b = [Person new];
  NSMutableArray *list = [[NSMutableArray alloc] init];
  [list addObject:a];
  [list addObject:b];
  NSString *s = [NSString stringWithUTF8String:"x"];
  [list addObject:s];
}
@end
