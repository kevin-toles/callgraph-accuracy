#include <QWidget>

class Shape {
 public:
  virtual ~Shape() = default;
  virtual double area() const { return 0.0; }
  double describe() const { return area() * 2; }
};

class Square : public Shape {
 public:
  double area() const override { return 4.0; }
  double twice() const { return this->describe() + describe(); }
};

class Handler {
 public:
  virtual ~Handler() = default;
  virtual void on_error(int code) = 0;
};

double total(const Shape& s, Square* sq, Handler& h) {
  h.on_error(1);
  return s.area() + sq->area() + sq->describe() + sq->twice();
}

class Panel : public QWidget {
 public:
  explicit Panel(QWidget* parent) : QWidget(parent) {}
  void refresh() {
    this->update();
    QWidget::setVisible(true);
  }
};
