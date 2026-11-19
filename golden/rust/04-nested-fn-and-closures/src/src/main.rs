struct Engine;

impl Engine {
    fn run(&self, xs: &Vec<i32>) {
        let step = |x: i32| self.fire(x);
        step(1);
        xs.iter().for_each(|x| self.fire(*x));
    }

    fn fire(&self, _x: i32) {}
}

fn outer() -> i32 {
    fn inner(a: i32) -> i32 {
        a * 2
    }
    let add = |a: i32, b: i32| inner(a) + b;
    add(1, 2)
}

fn main() {
    let e: Engine = Engine;
    let v = vec![1, 2];
    e.run(&v);
    outer();
}
