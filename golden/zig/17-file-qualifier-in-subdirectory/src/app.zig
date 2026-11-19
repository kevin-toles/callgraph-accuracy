const shapes = @import("geo/shapes.zig");

pub fn run() u32 {
    return shapes.area(1, 2);
}
