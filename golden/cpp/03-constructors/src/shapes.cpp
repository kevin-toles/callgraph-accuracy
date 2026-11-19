namespace geo {
int seed() { return 7; }

class Base {
 public:
  explicit Base(int v) : v_(seed() + v) {}

 private:
  int v_;
};

template <typename T>
class Box {
 public:
  explicit Box(T t) { (void)t; }
};

class Circle : public Base {
 public:
  Circle() : Circle(seed()) {}
  explicit Circle(int r) : Base(r), box_(new Box<int>(r)) {}

 private:
  Box<int>* box_;
};

Circle* make(int r) {
  Circle tmp = Circle(r);
  auto* heap = new Circle();
  (void)tmp;
  return heap ? heap : new Circle(r);
}
}  // namespace geo
