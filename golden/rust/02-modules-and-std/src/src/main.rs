use std::env;

mod util {
    pub fn clamp(v: i32) -> i32 {
        helper(v)
    }

    fn helper(v: i32) -> i32 {
        v
    }
}

fn main() {
    let v = util::clamp(3);
    let _w = crate::util::clamp(v);
    let _home = env::var("HOME");
    let _path = std::env::var("PATH");
    let _s = String::from("x");
    std::process::exit(0);
}
