package shop

import java.util.concurrent.*

class Item {
    String name

    Item(String name) {
        this.name = name
    }
}

class Special extends Item {
    int rank

    Special(String name, int rank) {
        super(name)
        this.rank = rank
    }

    Special(String name) {
        this(name, 0)
    }
}

class Maker {
    List<Item> make() {
        List<Item> items = new ArrayList<Item>()
        items.add(new Special("a"))
        ConcurrentHashMap<String, Item> idx = new ConcurrentHashMap<String, Item>()
        idx.clear()
        throw new IllegalStateException("x")
    }
}
