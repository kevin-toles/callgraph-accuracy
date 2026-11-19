enum Dir {
    North,
    South,
}

impl Dir {
    fn flip(self) -> Dir {
        match self {
            Dir::North => Dir::South,
            Dir::South => Dir::North,
        }
    }

    fn label(&self) -> &'static str {
        "d"
    }
}

fn main() {
    Dir::North.flip();
    Dir::South.label();
}
