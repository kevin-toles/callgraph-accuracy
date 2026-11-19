package com.acme.cfg

class Loader(private val name: String) {
    fun load(): Int {
        return 1
    }

    companion object {
        fun warm(): Int {
            return 0
        }
    }
}
