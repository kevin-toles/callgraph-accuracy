package com.acme.chain;

public class Pipeline {
    Pipeline start() {
        return this;
    }

    Pipeline filter() {
        return this;
    }

    Pipeline limit(int n) {
        return this;
    }

    void done() {
    }

    void run() {
        start()
            .filter()
            .filter()
            .done();
        this.start()
            .limit(3)
            .done();
    }
}
