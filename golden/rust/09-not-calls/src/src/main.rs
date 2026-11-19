enum Shape {
    Circle(f64),
    Empty,
}

struct Meters(u32);

struct Pt {
    x: i32,
}

impl Pt {
    fn double(v: i32) -> i32 {
        v * 2
    }

    fn convert(&self, xs: Vec<i32>) -> Option<Shape> {
        let _m = Meters(5);
        let _p = Pt { x: self.x };
        let _w = self.x as u64;
        let _c = Shape::Circle(1.0);
        let _e = Shape::Empty;
        let _r: Result<(), ()> = Ok(());
        let _d: Vec<i32> = xs.into_iter().map(Self::double).collect();
        Some(Shape::Empty)
    }
}

fn main() {}
