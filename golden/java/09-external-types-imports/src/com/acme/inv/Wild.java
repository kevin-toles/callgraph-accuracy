package com.acme.inv;

import java.util.*;

public class Wild {
    int run(String s) {
        Deque<String> q = new ArrayDeque<>();
        q.push(s);
        return q.size() + s.length();
    }
}
