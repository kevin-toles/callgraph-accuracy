#include "widget.h"

namespace ui {
void Engine::start() {}

int Widget::helper() const { return 1; }

void Widget::run() {
  engine_->start();
  this->engine_->start();
  backup_.start();
  draw(helper());
  this->draw(2);
}

void Widget::draw(int times) {
  for (int i = 0; i < times; i++) Painter::shared()->paint(*this);
}

Widget* Widget::create() { return nullptr; }

void Widget::Painter::paint(Widget& w) { w.run(); }

Widget::Painter* Widget::Painter::shared() { return nullptr; }
}  // namespace ui

void drive(ui::Widget& ref, ui::Widget* ptr) {
  ref.run();
  ptr->draw(3);
  ui::Widget* made = ui::Widget::create();
  made->run();
  ui::Widget::Painter::shared()->paint(ref);
}
