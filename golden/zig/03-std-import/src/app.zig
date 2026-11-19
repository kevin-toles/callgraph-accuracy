const std = @import("std");
const mem = std.mem;

pub fn check(a: []const u8, b: []const u8) !u32 {
    std.debug.print("{s}\n", .{a});
    if (std.mem.eql(u8, a, b)) {
        return 0;
    }
    _ = mem.indexOf(u8, a, b);
    return try std.fmt.parseInt(u32, a, 10);
}
