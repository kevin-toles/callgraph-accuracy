const Handler = struct {
    cb: *const fn (i32) i32,

    pub fn fire(self: Handler, v: i32) i32 {
        return self.cb(v);
    }
};

fn double(v: i32) i32 {
    return v * 2;
}

fn apply(f: *const fn (i32) i32, v: i32) i32 {
    return f(v);
}

pub fn run() i32 {
    const h: Handler = .{ .cb = &double };
    return apply(&double, 3) + h.fire(4);
}
