trait Greet {
    fn name(&self) -> String;

    fn hello(&self) -> String {
        self.name()
    }
}

struct Dog;

impl Greet for Dog {
    fn name(&self) -> String {
        String::from("dog")
    }
}

fn speak(g: &dyn Greet, boxed: Box<dyn Greet>, dog: Dog) {
    g.name();
    boxed.hello();
    dog.hello();
    dog.name();
}

fn main() {
    speak(&Dog, Box::new(Dog), Dog);
}
