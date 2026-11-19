#ifndef VEC_H
#define VEC_H

struct vec2 {
    int x;
    int y;
};

static inline int clamp_unit(int v) {
    return v < 0 ? 0 : (v > 1 ? 1 : v);
}

static inline int vec_len2(struct vec2 a) {
    return clamp_unit(a.x) + clamp_unit(a.y);
}

#include "vec.inl"

#endif
