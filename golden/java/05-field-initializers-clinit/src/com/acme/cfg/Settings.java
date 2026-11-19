package com.acme.cfg;

import java.util.ArrayList;
import java.util.List;

public class Settings {
    static final Settings DEFAULT = create();
    private final List<String> keys = new ArrayList<>();
    private final Loader loader = new Loader("app");

    static {
        Loader.warm();
    }

    static Settings create() {
        return new Settings();
    }

    int size() {
        return keys.size();
    }
}
