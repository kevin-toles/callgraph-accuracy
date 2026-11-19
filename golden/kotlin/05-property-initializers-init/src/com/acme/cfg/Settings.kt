package com.acme.cfg

import java.util.ArrayList

class Settings(path: String) {
    private val keys = ArrayList<String>()
    private val loader = Loader(path)
    private val size: Int

    init {
        size = Loader.warm()
    }

    fun count(): Int {
        return loader.load()
    }

    companion object {
        val DEFAULT = create()

        fun create(): Settings {
            return Settings("default")
        }
    }
}
