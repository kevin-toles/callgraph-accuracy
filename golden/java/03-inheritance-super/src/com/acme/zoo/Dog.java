package com.acme.zoo;

public class Dog extends Animal {
    public Dog(String name) {
        super(name);
    }

    public Dog() {
        this("rex");
    }

    @Override
    void speak() {
        super.speak();
        wag();
    }

    void wag() {
    }

    void play() {
        this.eat();
        eat();
        this.speak();
    }
}
