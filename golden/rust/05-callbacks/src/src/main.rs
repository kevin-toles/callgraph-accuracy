struct Button {
    on_click: fn(u32) -> u32,
}

impl Button {
    fn press(&self) -> u32 {
        (self.on_click)(1)
    }
}

fn double(x: u32) -> u32 {
    x * 2
}

fn apply<F: Fn(u32) -> u32>(f: F, x: u32) -> u32 {
    f(x)
}

fn make_adder(n: u32) -> impl Fn(u32) -> u32 {
    move |x| x + n
}

fn twice(g: &dyn Fn(u32) -> u32) -> u32 {
    g(2)
}

fn main() {
    let b = Button { on_click: double };
    b.press();
    let add = make_adder(1);
    add(2);
    apply(&add, 3);
    twice(&add);
}
