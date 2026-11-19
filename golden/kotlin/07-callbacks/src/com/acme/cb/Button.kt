package com.acme.cb

class Button(private val onClick: () -> Unit) {
    fun click() {
        onClick()
    }

    fun repeat(times: Int, action: (Int) -> Unit) {
        action(times)
        val local: () -> Unit = onClick
        local()
    }
}

fun runTwice(f: () -> Unit) {
    f()
    f()
}
