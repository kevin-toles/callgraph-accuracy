package com.acme.shop

object Pricing {
    fun parse(s: String): Int {
        return 0
    }

    fun total(a: String): Int {
        val cart = Cart()
        cart.add(a)
        cart.add(parse(a))
        return Pricing.parse(a)
    }
}
