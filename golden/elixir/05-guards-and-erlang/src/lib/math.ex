defmodule MyApp.Math do
  import :math, only: [sqrt: 1]

  def root(x) when is_number(x) do
    sqrt(x)
  end

  def table do
    :ets.new(:cache, [:set])
  end

  def size(t) when is_tuple(t), do: tuple_size(t)
end
