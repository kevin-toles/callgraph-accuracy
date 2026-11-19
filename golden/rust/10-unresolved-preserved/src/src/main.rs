fn load() -> usize {
    let raw = std::fs::read_to_string("cfg").unwrap();
    let n = raw.len();
    let handle = extcrate::open("x");
    handle.spin();
    extcrate::open("y").spin();
    "abc".to_uppercase();
    n
}

fn main() {
    load();
}
