package com.acme.app;

import static com.acme.util.Strings.slug;

public class Tool {
    String run(String s) {
        return slug(s);
    }
}
