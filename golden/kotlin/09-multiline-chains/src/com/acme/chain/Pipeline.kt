package com.acme.chain

class Pipeline {
    fun start(): Pipeline = this

    fun filter(): Pipeline = this

    fun limit(n: Int): Pipeline = this

    fun done() {
    }

    fun run() {
        start()
            .filter()
            .filter()
            .done()
        this.start()
            .limit(3)
            .done()
    }
}
