namespace nc {
class Widget {
 public:
  int run() const { return 1; }
};

int compute(int x) { return x * 2; }

int examine(const Widget& w, double d) {
  int (Widget::*method)() const = &Widget::run;
  int (*fn)(int) = compute;
  int a = static_cast<int>(d);
  int b = (int)d + int(d);
  auto n = sizeof(Widget) + alignof(Widget);
  decltype(d) e = d;
  return (w.*method)() + compute(a) + b + static_cast<int>(n + e) + (fn != nullptr);
}
}  // namespace nc
