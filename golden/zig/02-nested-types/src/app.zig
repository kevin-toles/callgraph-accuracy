const Outer = struct {
    pub const Inner = struct {
        v: i32,

        pub fn make(v: i32) Inner {
            return Inner{ .v = v };
        }

        pub fn get(self: Inner) i32 {
            return self.v;
        }
    };

    pub fn build() i32 {
        const i: Inner = Inner.make(3);
        return i.get();
    }
};

pub fn run() i32 {
    const i: Outer.Inner = Outer.Inner.make(1);
    return i.get() + Outer.build();
}
