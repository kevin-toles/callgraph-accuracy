pub struct Point {
    pub x: f64,
    pub y: f64,
}

impl Point {
    pub fn new(x: f64, y: f64) -> Self {
        Point { x, y }
    }

    pub fn dist(&self, other: &Point) -> f64 {
        self.x - other.x + self.y - other.y
    }
}

pub fn origin() -> Point {
    Point::new(0.0, 0.0)
}

pub fn spread(p: &Point) -> f64 {
    p.dist(&origin())
}
