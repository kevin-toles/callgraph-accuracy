#import <Foundation/Foundation.h>

static int twice(int v) {
  return v * 2;
}

@interface Shape : NSObject
+ (Shape *)make;
- (void)greet;
- (int)doX:(int)x withY:(int)y;
- (void)run;
@end

@implementation Shape
+ (Shape *)make {
  return nil;
}
- (void)greet {
}
- (int)doX:(int)x withY:(int)y {
  return twice(x) + y;
}
- (void)run {
  [self greet];
  Shape *other = [Shape make];
  [other doX:1 withY:2];
  [self doX:3 withY:4];
}
@end

void driveShape(Shape *s) {
  [s run];
}
