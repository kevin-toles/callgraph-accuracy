#define STATIC_CHECK(name, cond) typedef char name[(cond) ? 1 : -1]

STATIC_CHECK(int_is_wide, sizeof(int) >= 2);

static int handler(int x) {
    return x;
}

static int (*hook)(int) = handler;

STATIC_CHECK(ptr_is_wide, sizeof(void *) >= sizeof(int));

int fire(int x) {
    return hook(x) + handler(x);
}
