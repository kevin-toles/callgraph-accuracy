struct Stack<T> {
    items: Vec<T>,
}

impl<T> Stack<T> {
    fn new() -> Self {
        Stack { items: Vec::new() }
    }

    fn push(&mut self, item: T) {
        self.items.push(item);
    }
}

fn main() {
    let mut s = Stack::<u8>::new();
    s.push(1);
    let mut v = Vec::<u8>::with_capacity(4);
    v.push(2);
}
