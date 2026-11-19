#import "Counter.h"
#import "util.h"

@implementation Counter {
  int _value;
}
- (instancetype)init {
  self = [super init];
  return self;
}
- (void)increment {
  [self incrementBy:1];
}
- (void)incrementBy:(int)n {
  _value = clampValue(_value + n);
}
@end
