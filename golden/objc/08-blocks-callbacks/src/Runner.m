#import <Foundation/Foundation.h>

typedef void (^Handler)(int);

struct Ops {
  int (*cb)(int);
};

static int apply(int (*fp)(int), int v) {
  return fp(v);
}

static int useOps(struct Ops *ops) {
  return ops->cb(1);
}

static int inc(int v) {
  return v + 1;
}

@interface Runner : NSObject
@property(nonatomic, copy) Handler handler;
- (void)each:(void (^)(int))cb;
- (void)helper;
- (void)run;
@end

@implementation Runner
- (void)each:(void (^)(int))cb {
  cb(1);
}
- (void)helper {
}
- (void)run {
  void (^blk)(void) = ^{
    [self helper];
  };
  blk();
  [self each:^(int x) {
    [self helper];
  }];
  self.handler(3);
  apply(inc, 2);
}
@end
