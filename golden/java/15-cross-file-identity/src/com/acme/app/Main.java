package com.acme.app;

import com.acme.util.Formatter;
import com.acme.util.Strings;

public class Main {
    String go(Formatter f, String in) {
        String a = Strings.slug(in);
        String b = Strings.title(a);
        return f.format(b);
    }
}
