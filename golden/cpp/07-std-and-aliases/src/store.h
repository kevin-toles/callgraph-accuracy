#pragma once
#include <memory>
#include <vector>

namespace app {
class Item {
 public:
  explicit Item(int v);
  int value() const;
};

using ItemList = std::vector<Item>;
typedef Item Entry;
}  // namespace app
