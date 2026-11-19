defmodule MyApp.Gen do
  defmacro defhello(name) do
    quote do
      def unquote(name)(), do: IO.puts("hello")
    end
  end
end
