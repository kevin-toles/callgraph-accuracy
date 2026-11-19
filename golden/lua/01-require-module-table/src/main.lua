local util = require "util"
local strutil = require("lib.strutil")

local function run(input)
  local a = util.trim(input)
  local b = util.clean(a)
  return strutil.upper(b)
end

run(" x ")
