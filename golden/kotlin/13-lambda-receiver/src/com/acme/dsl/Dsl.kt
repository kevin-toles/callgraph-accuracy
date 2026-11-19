package com.acme.dsl

class Config {
    fun setName(n: String) {
    }

    fun edit(block: Config.() -> Unit): Config {
        block()
        return this
    }
}

class App {
    fun setName(n: String) {
    }

    fun build(): Config {
        val cfg = Config()
        cfg.edit {
            setName("svc")
        }
        setName("app")
        return cfg
    }
}
