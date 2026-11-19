#include <algorithm>
#include <vector>

namespace calc {
int helper(int x) { return x + 1; }

int run(std::vector<int>& v) {
  auto sq = [](int x) { return helper(x) * x; };
  int acc = 0;
  std::for_each(v.begin(), v.end(), [&acc](int x) { acc += helper(x); });
  auto add = [&](int y) {
    return sq(y) + acc;
  };
  return add(sq(2));
}
}  // namespace calc
