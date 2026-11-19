package shop

class Store {
    int total() {
        int a = this.price()
        int b = price()
        return a
    }

    int price() {
        return Store.base()
    }

    static int base() {
        return Pricing.round(5)
    }

    int open() {
        Clerk c = new Clerk()
        return c.serve()
    }

    static class Clerk {
        int serve() {
            return greet()
        }

        int greet() {
            return 1
        }
    }
}

class Pricing {
    static int round(int x) {
        return x
    }
}
