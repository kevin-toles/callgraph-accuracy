fn computeSize(k: usize) usize {
    return k * 4;
}

const Point = struct {
    x: i32,

    pub fn origin() Point {
        return .{ .x = 0 };
    }
};

const table_size = computeSize(4);
const default_point = Point.origin();

pub fn size() usize {
    return table_size + computeSize(1);
}
