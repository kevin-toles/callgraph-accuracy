package core

class Config {
    static final int DEFAULTS = compute()
    List<String> items = load()
    static int counter

    static {
        counter = compute()
    }

    static int compute() {
        return 4
    }

    List<String> load() {
        return new ArrayList<String>()
    }
}
