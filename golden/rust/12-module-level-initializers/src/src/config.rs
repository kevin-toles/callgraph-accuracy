pub const fn limit(base: usize) -> usize {
    base * 4
}

pub const MAX: usize = limit(8);

pub static NAME_LEN: usize = limit(2) + 1;
