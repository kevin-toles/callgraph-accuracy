local fmt = require "fmt"

local insert = table.insert
local pad = fmt.pad

local function collect(t)
  local out = {}
  for _, v in ipairs(t) do
    insert(out, tostring(v))
  end
  print(string.format("%d items", #out))
  return table.concat(out, ","), math.floor(os.time() / 60)
end

local label = pad("x")
local up = label:upper()
local rep = ("-"):rep(3)
collect({ up, rep })
