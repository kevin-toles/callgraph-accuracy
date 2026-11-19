package com.acme.events;

public abstract class Job {
    private final String name;

    protected Job(String name) {
        this.name = name;
    }

    abstract void exec();
}
