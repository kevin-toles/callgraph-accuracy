package app

case class Point(x: Int, y: Int)

class Plotter {
  def origin(): Point = Point(0, 0)
}
