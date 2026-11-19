local core = require "core"

local View = {}

function View.draw()
  return core.loop()
end

return View
