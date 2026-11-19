package com.acme.tree;

public class Outer {
    void visit() {
        Inner i = new Inner();
        i.walk();
        Outer.Leaf leaf = new Outer.Leaf();
        leaf.mark();
        Leaf.count();
    }

    void note() {
    }

    class Inner {
        void walk() {
            note();
            Deep d = new Deep();
            d.dive();
        }

        class Deep {
            void dive() {
            }
        }
    }

    static class Leaf {
        void mark() {
        }

        static void count() {
        }
    }
}
