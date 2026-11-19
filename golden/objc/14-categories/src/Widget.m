#import <Foundation/Foundation.h>

@interface Widget : NSObject
- (void)draw;
@end

@interface Widget (Extras)
- (void)highlight;
@end

@implementation Widget
- (void)draw {
  [self highlight];
}
@end

@implementation Widget (Extras)
- (void)highlight {
  [self draw];
}
@end

@interface NSString (Shout)
- (NSString *)shout;
@end

@implementation NSString (Shout)
- (NSString *)shout {
  return [self uppercaseString];
}
@end

void paint(Widget *w, NSString *s) {
  [w highlight];
  [s shout];
}
