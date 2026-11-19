defmodule MyApp.Util do
  def slug(s) do
    s |> String.downcase() |> dashes()
  end

  def dashes(s), do: String.replace(s, " ", "-")
end
