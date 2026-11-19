#include "util.h"

int clampValue(int v) {
  return v < 0 ? 0 : v;
}

int clampTwice(int v) {
  return clampValue(clampValue(v));
}
