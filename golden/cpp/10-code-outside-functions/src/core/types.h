#pragma once

int init_count();

class Registry {
 public:
  explicit Registry(int cap);
  void add(int v);

 private:
  int limit_ = init_count();
  int cap_;
};
