#import <Foundation/Foundation.h>

@protocol Greeter <NSObject>
- (void)greet;
- (void)greetName:(NSString *)name;
@end

namespace ui {

void announce(id<Greeter> g) {
  [g greet];
  [g greetName:@"x"];
}

class Host {
 public:
  void ping(id<Greeter> g);
};

void Host::ping(id<Greeter> g) {
  [g greet];
}

}  // namespace ui
