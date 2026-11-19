defmodule MyApp.Dyn do
  import Phoenix.HTML

  def go(mod, x) do
    mod.run(x)
    html_escape(x)
  end

  def chain(x), do: x.config.load()

  def computed, do: get_mod().start()

  defp get_mod, do: MyApp.Dyn
end
