use std::ops::Deref;

struct Engine;

impl Engine {
    fn start(&self) {}
}

struct Guard {
    inner: Engine,
}

impl Guard {
    fn release(&self) {}
}

impl Deref for Guard {
    type Target = Engine;

    fn deref(&self) -> &Engine {
        &self.inner
    }
}

fn run(g: Guard) {
    g.start();
    g.release();
}

fn main() {
    run(Guard { inner: Engine });
}
