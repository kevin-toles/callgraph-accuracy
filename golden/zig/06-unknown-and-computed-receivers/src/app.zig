const Point = struct {
    x: i32,

    pub fn len(self: Point) i32 {
        return self.x;
    }
};

fn makePoint(x: i32) Point {
    return .{ .x = x };
}

pub fn poke(w: anytype) i32 {
    w.write(1);
    w.inner.flush();
    return makePoint(2).len();
}
