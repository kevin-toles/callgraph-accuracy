#import "Counter.h"
#import "util.h"

int main(void) {
  @autoreleasepool {
    Counter *c = [[Counter alloc] init];
    [c increment];
    [c incrementBy:clampValue(5)];
  }
  return 0;
}
