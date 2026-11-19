package core

class Maker {
    Object make() {
        return new Object()
    }
}

class Dyn {
    void go(obj, Maker m) {
        obj.launch()
        def x = m.make()
        x.fire()
        m.make().toString()
        undefinedHelper(3)
    }
}
