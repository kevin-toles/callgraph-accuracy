defmodule MyApp.Funcs do
  def run(f, x) do
    f.(x)
  end

  def local_fn(x) do
    double = fn y -> twice(y) end
    double.(x)
  end

  def caps(list) do
    Enum.map(list, &twice/1)
    |> Enum.map(&String.upcase/1)
  end

  def dyn(x), do: apply(__MODULE__, :twice, [x])

  def twice(y), do: {y, y}
end
