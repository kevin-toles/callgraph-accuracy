#include <functional>

namespace ev {
int notify(int x) { return x; }

class Emitter {
 public:
  void set(std::function<void(int)> cb) { on_done_ = cb; }
  void fire(int v) {
    on_done_(v);
    this->on_done_(v + 1);
  }

 private:
  std::function<void(int)> on_done_;
};

int apply(int (*op)(int), const std::function<int(int)>& fn, int v) {
  return op(v) + (*op)(v) + fn(v);
}

int relay(int (*notify)(int)) { return notify(1); }

int wire(Emitter& e) {
  int (*local)(int) = &ev::notify;
  e.fire(local(2));
  return apply(notify, [](int x) { return x; }, 3) + relay(ev::notify);
}
}  // namespace ev
