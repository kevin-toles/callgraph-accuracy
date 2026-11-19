#pragma once

namespace geom {
class Shape {
 public:
  explicit Shape(double side);
  double area() const;
  double scaled(double k) const;

 private:
  double side_;
};

double total_area(const Shape& a, const Shape& b);
}  // namespace geom
