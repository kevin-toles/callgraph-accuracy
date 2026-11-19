#include "dxmath.h"

namespace scene {
class Counter {
 public:
  void inc() { ++n_; }
  int get() const { return n_; }

 private:
  int n_;
};

Counter* make_counter() { return nullptr; }

float step(DirectX::XMVECTOR a, DirectX::XMVECTOR b) {
  typedef Counter C;
  using Vec = DirectX::XMVECTOR;
  C* c = make_counter();
  c->inc();
  Vec r = DirectX::XMVectorAdd(a, b);
  r = DirectX::XMVectorScale(r, 2.0f);
  return r.x + static_cast<float>(c->get());
}
}  // namespace scene
