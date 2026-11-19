namespace util {
int clamp(int v) { return v < 0 ? 0 : v; }

int log(int v) { return clamp(v); }
int log(int a, int b) { return log(a) + log(b); }

namespace detail {
int mix(int a, int b) { return util::clamp(a) ^ clamp(b); }
}  // namespace detail

int blend(int a, int b) { return detail::mix(a, b) + util::detail::mix(b, a); }
}  // namespace util

int global_helper(int v) { return util::log(v, v); }

int main() { return global_helper(util::blend(1, 2)) + ::global_helper(3); }
