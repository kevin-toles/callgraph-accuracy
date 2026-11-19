local Object = require('core').Object
local utils = require('utils')
local Path = Object:extend()
function Path:initialize(encode)
  self.encode = encode
end
function Path:split(f, state)
  if self:isAbsolute(f) then end
  self:extend()
  self.encode(f)
  utils.dump(f)
  utils.bind(f)
  local handler = state.exception
  handler(f)
end
local Posix = Path:extend()
function Posix:isAbsolute(f) return true end
return { Path = Path, Posix = Posix }
