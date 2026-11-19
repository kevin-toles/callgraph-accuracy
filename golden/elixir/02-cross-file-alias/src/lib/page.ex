defmodule MyApp.Page do
  alias MyApp.Util

  def title(t) do
    Util.slug(t)
  end

  def raw(t), do: MyApp.Util.dashes(t)
end
