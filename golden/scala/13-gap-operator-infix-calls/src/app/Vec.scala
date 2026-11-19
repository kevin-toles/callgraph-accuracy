package app

class Vec(val x: Int) {
  def +(o: Vec): Vec = this
  def combine(o: Vec): Vec = this
}

class Physics {
  def step(a: Vec, b: Vec): Vec = {
    val c = a + b
    val d = a combine b
    a.+(b)
  }
}
