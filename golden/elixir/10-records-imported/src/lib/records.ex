defmodule MyApp.Records do
  require Record
  Record.defrecord(:user, Record.extract(:user, from_lib: "my_app/include/user.hrl"))
  Record.defrecord(:tree, name: nil, children: [])
end
