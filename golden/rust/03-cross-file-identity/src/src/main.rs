use shapes::geometry::{self, Point};

fn main() {
    let a = Point::new(1.0, 2.0);
    let b = geometry::origin();
    a.dist(&b);
    shapes::geometry::spread(&a);
}
