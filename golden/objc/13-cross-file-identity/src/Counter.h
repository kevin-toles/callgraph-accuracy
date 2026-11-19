#import <Foundation/Foundation.h>

@interface Counter : NSObject
- (instancetype)init;
- (void)increment;
- (void)incrementBy:(int)n;
@end
