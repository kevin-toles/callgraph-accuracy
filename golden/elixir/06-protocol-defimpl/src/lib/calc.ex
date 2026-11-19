defmodule MyApp.Calc do
  def total(shapes), do: Enum.map(shapes, &MyApp.Shape.area/1)
  def one(s), do: MyApp.Shape.area(s)
end
