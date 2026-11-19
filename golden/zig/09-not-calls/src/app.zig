const std = @import("std");

const Shape = union(enum) {
    circle: u32,
    square: u32,
};

const Err = error{Bad};

const Point = struct {
    x: u32,
    y: u32,
};

fn consume(p: Point) u32 {
    return p.x;
}

pub fn probe(v: u64) Err!u32 {
    const p = Point{ .x = 1, .y = 2 };
    const s = Shape{ .circle = 3 };
    const size = @sizeOf(Point);
    const small: u32 = @intCast(v);
    const wide = @as(u64, small);
    const f = &consume;
    _ = s;
    _ = size;
    _ = wide;
    _ = f;
    if (v == 0) return error.Bad;
    return consume(p);
}
