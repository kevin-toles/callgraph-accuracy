package core

interface Greeter {
    String greet()
}

abstract class Task {
    abstract void exec()
}

class Spawner {
    String helper() {
        return "h"
    }

    void make() {
        Runnable r = new Runnable() {
            void run() {
                helper()
            }
        }
        Greeter g = new Greeter() {
            String greet() {
                return helper()
            }
        }
        Task t = new Task() {
            void exec() {
                helper()
            }
        }
    }
}
