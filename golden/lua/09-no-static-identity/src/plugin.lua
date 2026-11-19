local P = {}

local function make()
  return {}
end

function P.install(obj)
  function obj.hook(x)
    return tostring(x)
  end
  obj.unhook = function()
    return P.helper()
  end
  return obj.hook(1), obj:unhook()
end

function P.reassigned()
  local T = {}
  T = make()
  function T.go()
    return P.helper()
  end
  return T.go()
end

function P.from_call()
  local R = setmetatable({}, {})
  R.run = function()
    return P.helper()
  end
  return R.run()
end

function P.indexed(name)
  local handlers = {}
  handlers[name] = function()
    return P.helper()
  end
  return handlers
end

function P.helper()
  return 1
end

return P
