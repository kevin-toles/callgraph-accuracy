package app

class Box {
  def size: Int = 3
  def doubled: Box = this
  def report(): Int = size
}

class Inspector(b: Box) {
  def check(): Int = b.size
  def deep(): Int = b.doubled.size
}
