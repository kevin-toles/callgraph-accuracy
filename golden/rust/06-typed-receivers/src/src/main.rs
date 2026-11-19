use std::sync::Arc;

struct Engine {
    rpm: u32,
}

impl Engine {
    fn new() -> Engine {
        Engine { rpm: 0 }
    }

    fn start(&self) -> u32 {
        self.rpm
    }
}

struct Car {
    engine: Engine,
}

static SPARE: Engine = Engine { rpm: 1 };

impl Car {
    fn drive(&self, other: &Engine, boxed: Box<Engine>) {
        self.engine.start();
        other.start();
        boxed.start();
        SPARE.start();
        let shared: Arc<Engine> = Arc::new(Engine::new());
        shared.start();
        let _copy = shared.clone();
        let local = Engine { rpm: 2 };
        local.start();
        let maybe: Option<Engine> = None;
        maybe.unwrap();
        let mut list: Vec<u32> = Vec::new();
        list.push(1);
    }
}

fn main() {}
