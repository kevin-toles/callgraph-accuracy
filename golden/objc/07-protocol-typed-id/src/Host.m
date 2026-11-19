#import <Foundation/Foundation.h>

@protocol Greeter <NSObject>
- (void)greet;
- (void)greetName:(NSString *)name;
@end

@interface Host : NSObject
@property(nonatomic, weak) id<Greeter> delegate;
- (void)notify:(id<Greeter>)g copier:(id<NSCopying>)c;
@end

@implementation Host
- (void)notify:(id<Greeter>)g copier:(id<NSCopying>)c {
  [g greet];
  [g greetName:@"n"];
  [self.delegate greet];
  id<Greeter> local = g;
  [local greet];
  [c copyWithZone:nil];
}
@end
