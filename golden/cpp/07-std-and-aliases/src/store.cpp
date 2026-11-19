#include "store.h"

#include <algorithm>

namespace app {
Item::Item(int v) { (void)v; }
int Item::value() const { return 1; }

int tally(ItemList& items, std::vector<int>& nums, Entry* e) {
  nums.push_back(e->value());
  std::sort(nums.begin(), nums.end());
  items.clear();
  std::unique_ptr<Item> owned = std::make_unique<Item>(3);
  int v = owned->value();
  int w = owned.get()->value();
  owned.reset();
  return v + w + static_cast<int>(nums.size());
}
}  // namespace app
