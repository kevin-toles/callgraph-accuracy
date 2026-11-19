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

class Holder {
    public Store store
}

class App {
    public Holder holder

    void run(Conf conf) {
        conf.getStore().save()
        this.holder.store.save()
        holder.store.save()
    }
}
