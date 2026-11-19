defmodule MyApp.Pipe do
  def process(text) do
    text
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(fn s -> keep?(s) end)
    |> Enum.join(";")
  end

  defp keep?(""), do: false
  defp keep?(_), do: true
end
