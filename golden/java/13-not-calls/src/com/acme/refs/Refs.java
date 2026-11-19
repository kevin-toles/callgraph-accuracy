package com.acme.refs;

import java.util.List;
import java.util.function.Function;

public class Refs {
    int x;

    @Deprecated
    void run(List<Object> items, Object o) {
        items.forEach(this::print);
        Function<Object, String> f = String::valueOf;
        String s = (String) o;
        int y = this.x;
        Point p = new Point();
        int z = p.x;
        Runnable r = Refs::noop;
        print(s);
    }

    void print(Object o) {
    }

    static void noop() {
    }
}
