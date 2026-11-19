package com.acme.shop;

public class Cart {
    private int total;

    public Cart() {
        reset();
    }

    public Cart(int start) {
        this.total = start;
    }

    void reset() {
        this.total = 0;
    }

    void add(int amount) {
        total += amount;
        log(amount);
    }

    void add(String amount) {
        this.add(Pricing.parse(amount));
    }

    void log(int amount) {
    }

    static Cart withItem(int amount) {
        Cart c = new Cart(amount);
        c.add(amount);
        return c;
    }
}
