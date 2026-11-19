int first(int v) {
    return v + 1;
}

int second(int v) {
    return v * 2;
}

int combine(int a, int b) {
    return a - b;
}

int pipeline(int v) {
    int r = combine(
        first(v),
        second(
            first(v)));
    return second
        (r);
}
