package core

class Store {
    void save() {
    }
}

class Conf {
    Store getStore() {
        return new Store()
    }
}

class App {
    void run(Conf conf) {
        conf.store.save()
    }
}
