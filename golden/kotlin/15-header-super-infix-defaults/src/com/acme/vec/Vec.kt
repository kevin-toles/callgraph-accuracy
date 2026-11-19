package com.acme.vec

open class Base(val label: String)

class Clock

class Vec(val x: Int) : Base(name()) {
    infix fun dot(o: Vec): Int = x * o.x

    fun scaled(k: Int = defaultK()): Vec = Vec(x * k)
}

fun name(): String = "vec"

fun defaultK(): Int = 1

class Svc(clock: Clock = Clock()) {
    fun use(a: Vec, b: Vec): Int {
        return a dot b
    }
}
