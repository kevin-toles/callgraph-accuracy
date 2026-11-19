local Object = {}
Object.__index = Object

function Object:extend()
  local cls = setmetatable({}, self)
  cls.__index = cls
  cls.super = self
  return cls
end

function Object:new()
end

function Object:describe()
  return "object"
end

return Object
