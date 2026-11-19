defmodule MyApp.Facade do
  defdelegate slug(s), to: MyApp.Util

  def title(s), do: slug(s)
end
