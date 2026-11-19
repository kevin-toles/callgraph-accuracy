fn count_flags() -> usize {
    std::env::args()
        .skip(1)
        .filter(|a| a.starts_with('-'))
        .count()
}

fn main() {
    count_flags();
}
