package com.acme.jobs

class Registry {
    fun lookup(key: String): Job {
        return Job()
    }

    fun first(): Job {
        return Job()
    }
}

class Job {
    fun start() {
    }
}
