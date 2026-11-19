const std = @import("std");

const Registry = struct {
    ids: std.AutoHashMap(u32, u32),

    pub fn add(self: *Registry, k: u32) !void {
        try self.ids.put(k, k);
    }
};

pub fn lookup(map: *std.AutoHashMap(u32, u32), k: u32) ?u32 {
    return map.get(k);
}

pub fn has(map: std.AutoHashMap(u32, u32), k: u32) bool {
    return map.contains(k);
}
