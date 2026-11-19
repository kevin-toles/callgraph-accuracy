#import <Foundation/Foundation.h>

@interface Engine : NSObject
- (void)start;
@end

@implementation Engine
- (void)start {
}
@end

typedef Engine MotorAlias;

static Engine *gEngine;

@interface Car : NSObject {
  Engine *_spare;
}
@property(nonatomic, strong) Engine *engine;
- (void)drive:(Engine *)param list:(NSArray<Engine *> *)all;
@end

@implementation Car
- (void)drive:(Engine *)param list:(NSArray<Engine *> *)all {
  [param start];
  [_spare start];
  [self.engine start];
  [gEngine start];
  MotorAlias *m = param;
  [m start];
  for (Engine *each in all) {
    [each start];
  }
  [all count];
  @try {
    [param start];
  } @catch (NSException *e) {
    [e reason];
  }
}
@end
