defmodule MyApp.Boot do
  @moduledoc "Boot."
  @default_name String.upcase("app")

  defstruct name: @default_name, opts: []

  @spec start(String.t()) :: %__MODULE__{}
  def start(name) do
    %__MODULE__{name: name, opts: Keyword.new()}
  end

  IO.puts("compiling")
end

MyApp.Boot.start("x")
