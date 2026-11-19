defmodule MyApp.Widget do
  use MyApp.DSL

  def build(x) do
    Registry.add(tag(x))
  end
end
