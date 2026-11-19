defmodule MyApp.Checks do
  use ExUnit.Case

  def must(x) do
    flunk(inspect(x))
  end
end
