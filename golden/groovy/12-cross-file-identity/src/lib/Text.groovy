package lib

interface Sink {
    void emit(String s)
}

class Text {
    static String clean(String s) {
        return s.trim()
    }

    static String twice(String s) {
        return clean(clean(s))
    }
}
