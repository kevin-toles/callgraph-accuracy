defmodule MyApp.Named do
  def unquote(:hello)(name) do
    String.capitalize(name)
  end

  def greet(n), do: hello(n)
end
