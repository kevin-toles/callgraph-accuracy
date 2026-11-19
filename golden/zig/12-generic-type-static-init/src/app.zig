const std = @import("std");

pub fn build(alloc: std.mem.Allocator) !u32 {
    var map: std.AutoHashMap(u32, u32) = std.AutoHashMap(u32, u32).init(alloc);
    defer map.deinit();
    try map.put(1, 2);
    return map.count();
}
