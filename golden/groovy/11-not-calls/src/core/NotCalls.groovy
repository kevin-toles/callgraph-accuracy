package core

class Rec {
    public int total
}

class Ops {
    void handle(int x) {
    }

    void visit(Closure f) {
    }

    int go(Object o, Rec r) {
        visit(this.&handle)
        visit(this::handle)
        Rec rr = (Rec) o
        return r.total
    }
}
