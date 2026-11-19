defmodule MyApp.Acc do
  require Record
  Record.defrecordp(:state, count: 0, items: [])

  def new, do: state()

  def count(s), do: state(s, :count)

  def push(s, item) do
    items = state(s, :items)
    state(s, items: [item | items], count: state(s, :count))
  end

  def to_list(s), do: state(s)

  def idx, do: state(:items)

  def tally(s), do: Enum.count(state(s, :items))
end
