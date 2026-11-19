const Point = struct {
    x: i32,

    pub fn init(x: i32) Point {
        return .{ .x = x };
    }
};

const Line = struct {
    start: Point,
    end: Point,
};

fn makePoint() Point {
    return .init(1);
}

pub fn makeLine() Line {
    const p: Point = .init(2);
    return .{
        .start = p,
        .end = .init(3),
    };
}
