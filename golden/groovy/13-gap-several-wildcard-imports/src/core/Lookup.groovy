package core

import java.util.concurrent.*
import java.nio.file.*

class Lookup {
    int go() {
        ConcurrentHashMap<String, Integer> m = new ConcurrentHashMap<String, Integer>()
        m.clear()
        return m.size()
    }
}
