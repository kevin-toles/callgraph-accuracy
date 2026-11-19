package zoo

class Animal {
    String speak() {
        return sound()
    }

    String sound() {
        return "..."
    }

    String describe() {
        return "animal"
    }
}

class Dog extends Animal {
    String describe() {
        String s = super.describe()
        return this.speak()
    }
}

class Keeper {
    String visit(Dog d) {
        return d.speak()
    }
}

class Worker extends Thread {
    void go() {
        start()
    }

    void run() {
        super.run()
    }
}
