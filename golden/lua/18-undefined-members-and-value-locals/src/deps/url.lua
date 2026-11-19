local URL = {}
local len, format
function len(s) return #s end
local function parse(url)
  local parsed = {}
  parsed.href = URL.format(parsed)
  return len(url)
end
function format(parsed)
  local len = 0
  len = 1
  return ""
end
URL.parse = parse
URL.format = format
return URL
