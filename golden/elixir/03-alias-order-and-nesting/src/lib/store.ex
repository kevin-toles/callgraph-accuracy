defmodule MyApp.Store do
  def early(k), do: Cache.get(k)

  defmodule Cache do
    def get(k), do: Map.get(%{}, k)
  end

  def late(k), do: Cache.get(k)

  def before_alias(s), do: U.slug(s)

  alias MyApp.Util, as: U
  require MyApp.Macros, as: M

  def after_alias(k) do
    U.slug(M.key(k))
  end

  def self_call(k), do: __MODULE__.late(k)
end
