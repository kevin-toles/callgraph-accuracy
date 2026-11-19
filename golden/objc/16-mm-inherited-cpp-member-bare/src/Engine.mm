#import <Foundation/Foundation.h>

namespace eng {

class Base {
 public:
  void reportError(const char *msg);
};

class Derived : public Base {
 public:
  void run();
};

void Base::reportError(const char *msg) {
}

void Derived::run() {
  reportError("failed");
  this->reportError("again");
}

}  // namespace eng

void drive(eng::Derived *d) {
  d->run();
}
