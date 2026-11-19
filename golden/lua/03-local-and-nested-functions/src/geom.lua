local M = {}

local function square(x)
  return x * x
end

local cube = function(x)
  return x * square(x)
end

function M.area(sides)
  local function scaled(v)
    return square(v) * 2
  end
  local half = function(v)
    return scaled(v) / 2
  end
  table.sort(sides, function(a, b)
    return cube(a) < cube(b)
  end)
  return half(sides[1])
end

M.unit = square(1)

return M
