package core

class Node {
    Node next() {
        return this
    }

    String name() {
        return "n"
    }
}

class Walker {
    private Node root

    String walk() {
        return root
            .next()
            .next()
            .name()
    }
}
