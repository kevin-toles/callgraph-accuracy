struct Worker;

impl Worker {
    fn run(&self) {}
}

enum Msg {
    Job(Worker),
    Stop,
}

fn handle(msg: Msg, next: Option<Worker>) {
    match msg {
        Msg::Job(w) => w.run(),
        Msg::Stop => {}
    }
    if let Some(n) = next {
        n.run();
    }
}

fn main() {
    handle(Msg::Stop, None);
}
