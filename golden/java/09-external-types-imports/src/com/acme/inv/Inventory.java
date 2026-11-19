package com.acme.inv;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Inventory {
    int count(String raw) {
        List<String> items = new ArrayList<>();
        items.add(raw.trim());
        Map<String, Integer> byName = new HashMap<>();
        byName.put(raw, Integer.parseInt(raw));
        var cache = new HashMap<String, String>();
        cache.clear();
        java.util.Objects.requireNonNull(raw);
        return Math.max(items.size(), 1);
    }
}
