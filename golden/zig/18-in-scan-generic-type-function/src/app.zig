fn Stack(comptime T: type) type {
    return struct {
        items: [8]T = undefined,
        len: usize = 0,

        pub fn push(self: *@This(), v: T) void {
            self.items[self.len] = v;
            self.len += 1;
        }
    };
}

pub fn run() usize {
    var s: Stack(u8) = .{};
    s.push(1);
    return s.len;
}
