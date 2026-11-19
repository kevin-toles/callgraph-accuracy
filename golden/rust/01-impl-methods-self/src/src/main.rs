struct Counter {
    count: u32,
}

impl Counter {
    fn new() -> Self {
        Self::with_start(0)
    }

    fn with_start(count: u32) -> Self {
        Counter { count }
    }

    fn bump(&mut self) {
        self.count += 1;
        self.check();
        Counter::check_static(self.count);
    }

    fn check(&self) {}

    fn check_static(_n: u32) {}
}

fn main() {
    let mut c = Counter::new();
    c.bump();
}
