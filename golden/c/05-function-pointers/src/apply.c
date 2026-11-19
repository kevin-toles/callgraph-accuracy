typedef int (*unary_fn)(int);

static unary_fn g_hook;

int inc(int x) {
    return x + 1;
}

int notify(int x) {
    return x;
}

int apply(int (*fn)(int), int v) {
    return fn(v) + (*fn)(v);
}

int run(int (*notify)(int)) {
    return notify(3);
}

int compose(int v) {
    unary_fn op = inc;
    int (*local)(int) = &notify;
    g_hook = inc;
    return op(v) + local(v) + g_hook(v) + apply(inc, v);
}
