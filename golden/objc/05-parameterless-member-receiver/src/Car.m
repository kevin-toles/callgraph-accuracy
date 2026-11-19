#import <Foundation/Foundation.h>

@interface Engine : NSObject
- (void)start;
@end

@implementation Engine
- (void)start {
}
@end

@interface Car : NSObject
- (Engine *)engine;
- (Engine *)engineAt:(int)i;
- (void)go;
@end

@implementation Car
- (Engine *)engine {
  return nil;
}
- (Engine *)engineAt:(int)i {
  return nil;
}
- (void)go {
  [[self engine] start];
  [[self engineAt:0] start];
}
@end
