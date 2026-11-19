struct point {
    int x;
    int y;
};

int make_x(void);

int make_x(void) {
    return (int)sizeof(struct point);
}

int make_y(int seed) {
    return (seed);
}

long build(int seed) {
    struct point p = { make_x(), make_y(seed) };
    struct point q = (struct point){ .x = seed, .y = (int)(long)seed };
    int (*getter)(void) = make_x;
    (void)make_y(p.x);
    return (long)(q.x + p.y) + (long)sizeof(q) + (long)(getter != 0);
}
