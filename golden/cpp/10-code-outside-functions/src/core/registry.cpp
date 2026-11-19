#include "types.h"

int init_count() { return 4; }

Registry::Registry(int cap) : cap_(cap) {}

void Registry::add(int v) { cap_ += v; }

static int g_count = init_count();
Registry* g_reg = new Registry(g_count);

void use() {
  g_reg->add(init_count());
}
