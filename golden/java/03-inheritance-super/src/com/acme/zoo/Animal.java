package com.acme.zoo;

public class Animal {
    protected String name;

    public Animal(String name) {
        this.name = name;
    }

    void speak() {
    }

    void eat() {
        speak();
    }
}
