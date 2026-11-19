const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const bump = increment;

fn increment(v: u32) u32 {
    return v + 1;
}

pub fn run(v: u32) u32 {
    assert(v < 100);
    print("{d}\n", .{v});
    const inc = increment;
    return inc(bump(v));
}
