package com.acme.fi;

import java.util.function.Function;

public class Apply {
    int run(Function<String, Integer> f, Handler h, String s) {
        Runnable r = () -> h.handle(s);
        r.run();
        return f.apply(s);
    }
}
