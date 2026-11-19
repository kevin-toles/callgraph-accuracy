macro_rules! square {
    ($x:expr) => {
        $x * $x
    };
}

fn compute(n: i32) -> i32 {
    square!(n)
}

fn main() {
    println!("{}", compute(2));
    let _v = vec![compute(3)];
    assert_eq!(square!(compute(1)), 1);
}
