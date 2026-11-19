#include <cassert>

#define CHECK_POSITIVE(x) ((x) > 0)

namespace guard {
int validate(int v) { return v + 1; }

int check(int v) {
  assert(validate(v) > 0);
  assert(CHECK_POSITIVE(v));
  return CHECK_POSITIVE(validate(v)) ? v : 0;
}
}  // namespace guard
