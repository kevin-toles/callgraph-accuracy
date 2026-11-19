package core

class Spec {
    void name(String n) {
    }
}

class Runner {
    void visit(Closure c) {
        c(1)
    }

    void log(Object v) {
    }

    void configure(Closure body) {
        body.setDelegate(new Spec())
        body()
    }

    int compute() {
        def twice = { int x -> x }
        visit { v -> log(v) }
        configure {
            name("x")
        }
        return twice(3)
    }
}
