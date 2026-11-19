local Object = require "object"

local View = Object:extend()

function View:new()
  View.super.new(self)
  self.size = 0
end

function View:draw()
  return self:describe()
end

return View
