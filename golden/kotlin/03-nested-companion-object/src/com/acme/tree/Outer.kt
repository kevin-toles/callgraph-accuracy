package com.acme.tree

class Outer {
    fun visit() {
        val n = Nested()
        n.walk()
        val o: Outer = Outer.create()
        o.visit()
        create()
        Registry.add("x")
    }

    class Nested {
        fun walk() {
            val d = Deep()
            d.dive()
        }

        class Deep {
            fun dive() {
            }
        }
    }

    companion object {
        fun create(): Outer {
            return Outer()
        }
    }
}

object Registry {
    fun add(key: String) {
    }
}
