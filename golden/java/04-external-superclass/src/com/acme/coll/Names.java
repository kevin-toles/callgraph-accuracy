package com.acme.coll;

import java.util.ArrayList;

public class Names extends ArrayList<String> {
    public Names(int capacity) {
        super(capacity);
    }

    @Override
    public boolean add(String s) {
        return super.add(s.trim());
    }
}
