const util = @import("util.zig");
const Vec = util.Vec;
const add = util.add;

pub fn run() i32 {
    const v: Vec = .{ .x = -3 };
    const w: util.Vec = .{ .x = 4 };
    return util.add(v.len(), w.len()) + add(1, 2) + util.abs(-1);
}
