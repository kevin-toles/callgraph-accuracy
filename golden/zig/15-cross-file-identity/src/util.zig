pub const Vec = struct {
    x: i32,

    pub fn len(self: Vec) i32 {
        return abs(self.x);
    }
};

pub fn abs(v: i32) i32 {
    return if (v < 0) -v else v;
}

pub fn add(a: i32, b: i32) i32 {
    return abs(a) + abs(b);
}
