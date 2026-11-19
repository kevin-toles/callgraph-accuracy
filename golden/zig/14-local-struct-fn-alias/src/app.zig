fn outer(v: i32) i32 {
    const g = struct {
        fn g(x: i32) i32 {
            return helper(x);
        }
    }.g;
    return g(v);
}

fn helper(x: i32) i32 {
    return x + 1;
}

pub fn run() i32 {
    return outer(1);
}
