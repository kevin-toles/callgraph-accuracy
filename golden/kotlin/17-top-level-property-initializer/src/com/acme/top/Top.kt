package com.acme.top

class Registry {
    fun add(key: String) {
    }
}

val registry = Registry()

fun use() {
    registry.add("k")
}
