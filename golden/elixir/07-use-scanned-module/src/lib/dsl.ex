defmodule MyApp.DSL do
  defmacro __using__(_opts) do
    quote do
      import MyApp.DSL.Helpers
      alias MyApp.DSL.Registry
    end
  end
end
