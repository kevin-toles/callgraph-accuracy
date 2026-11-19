defmodule MyApp.Text do
  def normalize(words) do
    words
    |> Enum.map(fn w -> clean(w) end)
    |> Enum.reject(&blank?/1)
  end

  def count(words) do
    length(words)
  end

  defp clean(w) do
    String.downcase(String.trim(w))
  end

  defp blank?(""), do: true
  defp blank?(_), do: false

  def reversed(list), do: :lists.reverse(list)
end
