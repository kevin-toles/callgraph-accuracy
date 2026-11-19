#pragma once

namespace ui {
class Engine {
 public:
  void start();
};

class Widget {
 public:
  void run();
  void draw(int times);
  static Widget* create();

  class Painter {
   public:
    void paint(Widget& w);
    static Painter* shared();
  };

 private:
  int helper() const;
  Engine* engine_;
  Engine backup_;
};
}  // namespace ui
