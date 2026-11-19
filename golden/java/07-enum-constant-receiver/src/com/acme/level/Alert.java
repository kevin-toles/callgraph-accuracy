package com.acme.level;

public class Alert {
    int score() {
        return Level.HIGH.weight() + Level.LOW.weight();
    }
}
