package com.acme.shop;

public class Pricing {
    static int parse(String s) {
        return 0;
    }

    static int total(String a, String b) {
        Cart cart = new Cart();
        cart.add(a);
        cart.add(parse(b));
        return Pricing.parse(a);
    }
}
