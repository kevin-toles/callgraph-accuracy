#include "scale.h"

int scale(int v, int factor) {
    return v * factor;
}

int scale_twice(int v) {
    return scale(scale(v, 2), 2);
}
