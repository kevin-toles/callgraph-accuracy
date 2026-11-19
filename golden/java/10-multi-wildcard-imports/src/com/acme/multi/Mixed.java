package com.acme.multi;

import java.io.*;
import java.util.*;

public class Mixed {
    int run(String s) {
        List<String> xs = new ArrayList<>();
        xs.add(s);
        StringWriter w = new StringWriter();
        w.write(s);
        return xs.size() + s.length();
    }
}
