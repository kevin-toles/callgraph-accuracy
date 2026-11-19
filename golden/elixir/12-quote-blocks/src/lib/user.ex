defmodule MyApp.GenUser do
  require MyApp.Gen
  MyApp.Gen.defhello(:hi)

  def run, do: hi()
end
