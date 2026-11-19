local resolver = require "resty.dns.resolver"
local utils = require("pl.utils")
local function setup()
  local old_new = resolver.new
  resolver.new = function(...)
    return old_new(...)
  end
  utils.readlines = function(name)
    return {}
  end
end
setup()
return { setup = setup }
