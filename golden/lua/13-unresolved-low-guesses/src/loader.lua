local name = "plugins." .. "extra"
local extra = require(name)
local json = require "json"

local function load(cfg)
  extra.setup(cfg)
  local data = json.decode(cfg.raw)
  cfg.target:apply(data)
  undefined_global(data)
  return data
end

load({})

return true
