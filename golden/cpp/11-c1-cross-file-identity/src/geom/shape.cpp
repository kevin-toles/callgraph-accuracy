#include "shape.h"

namespace geom {
Shape::Shape(double side) : side_(side) {}

double Shape::area() const { return side_ * side_; }

double Shape::scaled(double k) const { return area() * k; }

double total_area(const Shape& a, const Shape& b) { return a.area() + b.area(); }
}  // namespace geom
