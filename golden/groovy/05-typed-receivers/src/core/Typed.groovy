package core

interface Svc {
    int work()
}

class FastSvc implements Svc {
    int work() {
        return 1
    }
}

class Holder {
    private Svc svc

    int viaField() {
        return svc.work()
    }

    int viaParam(FastSvc s) {
        return s.work()
    }

    int viaLocal() {
        Svc s = new FastSvc()
        def f = new FastSvc()
        s.work()
        return f.work()
    }

    int viaLoop(List<FastSvc> all) {
        for (FastSvc x : all) {
            x.work()
        }
        return 0
    }

    String viaCatch() {
        try {
            return "ok"
        } catch (IllegalArgumentException e) {
            return e.getMessage()
        }
    }

    static <T extends Svc> int viaBound(T t) {
        return t.work()
    }

    String viaString(String name) {
        return name.toUpperCase()
    }
}
