package com.acme.io;

import java.io.Closeable;
import java.util.Map;

public class Closer {
    void close(Map<String, Closeable> handles, String key) throws Exception {
        handles.get(key).close();
        String n = key.getClass().getName();
        System.out.println(n);
        "done".trim();
    }
}
