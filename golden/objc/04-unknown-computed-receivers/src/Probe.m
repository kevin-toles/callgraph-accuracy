#import <Foundation/Foundation.h>

struct Slot {
  id bar;
};

@interface Probe : NSObject
- (void)poke:(id)obj slot:(struct Slot *)s;
@end

@implementation Probe
- (void)poke:(id)obj slot:(struct Slot *)s {
  [obj spin];
  [obj frobnicate:1 with:2];
  [s->bar go];
  id items[2] = {obj, obj};
  [items[0] go];
  [@"abc" length];
  [[obj thing] go];
}
@end
