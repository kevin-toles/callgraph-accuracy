package com.acme.zoo

open class Animal(val name: String) {
    open fun speak() {
    }

    fun eat() {
        speak()
    }
}
