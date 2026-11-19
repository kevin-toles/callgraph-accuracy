#import <Foundation/Foundation.h>
#import "macros.h"

#define SQUARE(x) ((x) * (x))

static int compute(int v) {
  return v + 1;
}

@interface Calc : NSObject
- (int)value;
@end

@implementation Calc
- (int)value {
  int a = SQUARE(compute(2));
  int b = CLAMP(a, 0, LIMIT);
  return SQUARE(b);
}
@end
