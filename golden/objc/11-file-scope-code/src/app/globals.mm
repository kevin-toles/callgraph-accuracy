#import <Foundation/Foundation.h>

@interface Registry : NSObject
+ (instancetype)make;
@end

@implementation Registry
+ (instancetype)make {
  return [[self alloc] init];
}
@end

static int computeCount() {
  return 3;
}

static Registry *gRegistry = [Registry make];
static int gCount = computeCount();
