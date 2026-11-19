#import <Foundation/Foundation.h>

struct Pt {
  int x;
  int y;
};

static int helper(int v) {
  return v;
}

static int apply(int (*fp)(int)) {
  return 0;
}

@interface Probe : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic) NSUInteger count;
- (void)check;
@end

@implementation Probe
- (void)check {
  self.name = @"x";
  NSUInteger n = self.count;
  struct Pt p = {1, 2};
  long size = sizeof(p);
  double d = (double)n;
  SEL sel = @selector(check);
  [self respondsToSelector:@selector(check)];
  apply(helper);
  void (^unused)(void) = ^{
  };
}
@end
