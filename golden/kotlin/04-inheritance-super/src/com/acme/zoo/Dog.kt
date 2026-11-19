package com.acme.zoo

class Dog : Animal {
    constructor(name: String) : super(name)

    constructor() : this("rex")

    override fun speak() {
        super.speak()
        wag()
    }

    fun wag() {
    }

    fun play() {
        this.eat()
        eat()
        this.speak()
    }
}
