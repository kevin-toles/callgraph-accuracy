defimpl MyApp.Shape, for: MyApp.Circle do
  def area(c), do: square(c.r)
  defp square(r), do: :math.pow(r, 2)
end

defimpl MyApp.Shape, for: [MyApp.Square, MyApp.Rect] do
  def area(s), do: dims(s)
  defp dims(s), do: Tuple.to_list(s.dims)
end
