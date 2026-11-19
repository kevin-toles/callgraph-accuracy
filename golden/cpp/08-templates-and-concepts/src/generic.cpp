#include <concepts>

class Shape {
 public:
  double area() const { return 1.0; }
};

template <std::derived_from<Shape> T>
double bounded(const T& t) {
  return t.area();
}

template <typename T>
double unbounded(T& t) {
  t.area();
  t.child.area();
  return t.make().area();
}

double use(const Shape& s) { return bounded(s); }
