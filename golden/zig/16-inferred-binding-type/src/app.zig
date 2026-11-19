const Point = struct {
    x: i32,

    pub fn init(x: i32) Point {
        return .{ .x = x };
    }

    pub fn len(self: Point) i32 {
        return self.x;
    }
};

pub fn run() i32 {
    const a = Point.init(1);
    const b = Point{ .x = 2 };
    return a.len() + b.len();
}
