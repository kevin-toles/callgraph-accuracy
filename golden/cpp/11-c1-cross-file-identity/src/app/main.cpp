#include "../geom/shape.h"

int main() {
  geom::Shape s = geom::Shape(2.0);
  geom::Shape* p = new geom::Shape(3.0);
  return static_cast<int>(s.area() + p->scaled(2.0) + geom::total_area(s, *p));
}
