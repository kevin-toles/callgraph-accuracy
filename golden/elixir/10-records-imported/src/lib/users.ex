defmodule MyApp.Users do
  import MyApp.Records

  def new(name), do: user(name: String.trim(name))

  def name(user(name: n)), do: n

  def rename(u, n), do: user(u, name: n)

  def leaf(t) do
    case t do
      tree(children: []) -> true
      tree(children: kids) -> Enum.empty?(kids)
    end
  end
end
