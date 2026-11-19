package com.acme.refs

class Refs(val x: Int) {
    @Deprecated("old")
    fun run(o: Any, p: Point) {
        val f = ::helper
        val g = this::print
        val h = Refs::noop
        val s = o as String
        val y = this.x
        val z = p.y
        print(s)
    }

    fun print(o: Any) {
    }

    fun noop() {
    }
}

fun helper() {
}
