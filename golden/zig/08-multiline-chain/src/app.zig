const Builder = struct {
    n: i32,

    pub fn add(self: Builder, k: i32) Builder {
        return .{ .n = self.n + k };
    }
};

pub fn build() i32 {
    const b: Builder = .{ .n = 0 };
    const r = b
        .add(1)
        .add(2)
        .add(3);
    return r.n;
}
