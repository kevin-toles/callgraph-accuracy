package com.acme.jobs

import java.util.ArrayList

class Scheduler(private val registry: Registry) {
    fun kick() {
        val list = ArrayList<Job>()
        list.add(Job())
        list.get(0).start()
        registry.lookup("a").start()
        registry.first().start()
    }
}
