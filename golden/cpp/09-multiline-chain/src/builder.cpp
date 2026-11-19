namespace q {
class Builder {
 public:
  Builder() : count_(0) {}
  Builder& self() { return *this; }
  Builder& add(int v) {
    count_ += v;
    return *this;
  }
  int build() const { return count_; }

 private:
  int count_;
};

int assemble(Builder& b) {
  return b.self()
      .add(1)
      .add(2)
      .build();
}
}  // namespace q
