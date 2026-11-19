defmodule MyApp.Shapes do
  import Record
  defrecord :point, x: 0, y: 0
  defrecordp :box, w: String.length("ab"), h: 1

  def origin, do: point()

  def make(x), do: point(x: abs(x), y: String.length("ab"))

  def x_of(point(x: x)), do: x

  def width(b) do
    box(w: w) = b
    w
  end

  def widen(b, w), do: box(b, w: max(w, 1))
end
