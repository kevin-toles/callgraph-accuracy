#include "vec.h"

int main(void) {
    struct vec2 a = { 1, 2 };
    return vec_dot(a, a) + clamp_unit(a.x);
}
