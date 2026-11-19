const Point = struct {
    x: i32,
    y: i32,

    pub fn origin() Point {
        return Point{ .x = 0, .y = 0 };
    }

    pub fn len(self: Point) i32 {
        return self.x + self.y;
    }

    pub fn scaled(self: Point, k: i32) i32 {
        return scale(self.len(), k);
    }

    fn scale(v: i32, k: i32) i32 {
        return v * k;
    }
};

fn helper(v: i32) i32 {
    return v + 1;
}

pub fn main() void {
    const p: Point = Point.origin();
    _ = p.len();
    _ = Point.len(p);
    _ = helper(p.scaled(2));
}
