namespace fx {
class Adder {
 public:
  explicit Adder(int base) : base_(base) {}
  int operator()(int x) const { return x + base_; }

 private:
  int base_;
};

struct Holder {
  Adder adder;
};

int apply(const Adder& add, Holder* h, int v) {
  Adder local = Adder(v);
  return add(v) + h->adder(v) + local(1) + add.operator()(2);
}
}  // namespace fx
