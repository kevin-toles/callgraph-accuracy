defmodule MyApp.Pairs do
  require Record
  Record.defrecord(:pair, left: nil, right: nil)

  def left(p), do: pair(p, :left)

  def swap(pair(left: l, right: r)), do: pair(left: r, right: l)
end
