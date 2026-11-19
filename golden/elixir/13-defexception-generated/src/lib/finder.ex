defmodule MyApp.Finder do
  def error(id) do
    e = MyApp.NotFound.exception(message: inspect(id))
    MyApp.NotFound.message(e)
  end

  def text(e), do: Exception.message(e)
end
