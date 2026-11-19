package com.acme.shop

class Cart(private var total: Int) {
    constructor() : this(0) {
        reset()
    }

    fun reset() {
        total = 0
    }

    fun add(amount: Int) {
        total += amount
        log(amount)
    }

    fun add(amount: String) {
        this.add(Pricing.parse(amount))
    }

    private fun log(amount: Int) {
    }
}
