package com.acme.fn

class Worker {
    fun run(items: List<String>) {
        val shout = { s: String -> emit(s) }
        fun whisper(s: String) {
            emit(s)
        }
        shout("a")
        whisper("b")
        each(items) { emit(it) }
        val l: Listener = object : Listener {
            override fun on(e: String) {
                emit(e)
            }
        }
        val t: Task = object : Task("x") {
            override fun exec() {
                emit("job")
            }
        }
        l.on("start")
        t.exec()
    }

    fun each(xs: List<String>, f: (String) -> Unit) {
        for (x in xs) {
            f(x)
        }
    }

    fun emit(s: String) {
    }
}
