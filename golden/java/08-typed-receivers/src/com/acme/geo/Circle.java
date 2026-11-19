package com.acme.geo;

public class Circle implements Shape {
    private final double r;

    public Circle(double r) {
        this.r = r;
    }

    public double area() {
        return r * r;
    }

    public double radius() {
        return r;
    }
}
