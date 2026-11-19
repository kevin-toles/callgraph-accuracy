static inline int vec_dot(struct vec2 a, struct vec2 b) {
    return a.x * b.x + a.y * b.y + vec_len2(a);
}
