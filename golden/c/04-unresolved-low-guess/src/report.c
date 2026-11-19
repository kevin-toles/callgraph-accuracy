int known(int x) {
    return x + 1;
}

int report(int code) {
    int r = known(code);
    log_event(r);
    return format_code(known(r));
}
