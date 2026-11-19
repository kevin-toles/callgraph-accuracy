#import <Foundation/Foundation.h>

@interface Builder : NSObject
- (instancetype)initWithName:(NSString *)name;
- (Builder *)build;
- (void)setWidth:(int)w height:(int)h;
@end

@implementation Builder
- (instancetype)initWithName:(NSString *)name {
  return self;
}
- (Builder *)build {
  return self;
}
- (void)setWidth:(int)w height:(int)h {
}
@end

void assemble(void) {
  Builder *b = [[[Builder alloc]
      initWithName:@"a"]
      build];
  [b setWidth:1
       height:2];
}
