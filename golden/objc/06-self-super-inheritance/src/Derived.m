#import <Foundation/Foundation.h>

@interface Base : NSObject
- (void)baseWork;
@end

@implementation Base
- (void)baseWork {
}
@end

@interface Derived : Base
- (void)derivedWork;
- (void)run;
@end

@implementation Derived
- (void)derivedWork {
}
- (void)run {
  [self derivedWork];
  [self baseWork];
  [super baseWork];
  [self description];
}
@end
