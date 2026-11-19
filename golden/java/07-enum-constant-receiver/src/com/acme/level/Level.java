package com.acme.level;

public enum Level {
    LOW(1),
    HIGH(5);

    private final int weight;

    Level(int weight) {
        this.weight = weight;
    }

    int weight() {
        return weight;
    }

    static int max() {
        return HIGH.weight();
    }
}
