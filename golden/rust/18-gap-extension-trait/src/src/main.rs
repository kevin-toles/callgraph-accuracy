trait Shout {
    fn shout(&self) -> String;
}

impl Shout for String {
    fn shout(&self) -> String {
        String::new()
    }
}

impl Shout for str {
    fn shout(&self) -> String {
        String::new()
    }
}

fn main() {
    let s: String = String::from("hi");
    s.shout();
    let r: &str = "yo";
    r.shout();
}
