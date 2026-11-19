local E = {}

local function default_handler(msg)
  return msg
end

function E.dispatch(handler, msg)
  local h = handler or default_handler
  local result = h(msg)
  return handler(result)
end

function E.make()
  local fn = E.factory()
  return fn()
end

function E.factory()
  return default_handler
end

function E.wire(list)
  table.sort(list, E.compare)
  local ref = E.compare
  local size = #list
  local t = { a = E.compare, n = size }
  return t.n, ref
end

function E.compare(a, b)
  return a < b
end

return E
