const Point = struct {
    x: i32,

    pub fn len(self: Point) i32 {
        return self.x;
    }
};

const Color = enum {
    red,
    green,

    pub fn label(self: Color) []const u8 {
        return switch (self) {
            .red => "r",
            .green => "g",
        };
    }
};

const P = Point;

var origin: Point = .{ .x = 0 };

pub fn sum(ptr: *Point, points: []const Point, maybe: ?Point) i32 {
    var total: i32 = ptr.len() + origin.len();
    const q: P = .{ .x = 2 };
    total += q.len();
    for (points) |pt| {
        total += pt.len();
    }
    if (maybe) |m| {
        total += m.len();
    }
    const c: Color = .green;
    _ = c.label();
    _ = Color.red.label();
    return total;
}
