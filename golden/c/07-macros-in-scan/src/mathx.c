#include "mathx.h"

#define TWICE(x) (2 * (x))

static int base(int v) {
    return v + LIMIT;
}

int compute(int v) {
    int s = SQUARE(base(v));
    int m = MAX(s,
                TWICE(base(s)));
    return m > LIMIT ? m : SQUARE(m);
}
