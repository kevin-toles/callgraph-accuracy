trait Clock {
    fn now(&self) -> u64;
}

trait Backend {
    fn now(&self) -> u64;
}

struct Sys;

impl Clock for Sys {
    fn now(&self) -> u64 {
        0
    }
}

fn tick<T: Clock>(c: &T) -> u64 {
    c.now()
}

fn tock<T>(c: T) -> u64
where
    T: Clock,
{
    c.now()
}

struct Service<B: Backend> {
    backend: B,
}

impl<B: Backend> Service<B> {
    fn poll(&self) -> u64 {
        self.backend.now()
    }
}

fn main() {
    tick(&Sys);
    tock(Sys);
}
