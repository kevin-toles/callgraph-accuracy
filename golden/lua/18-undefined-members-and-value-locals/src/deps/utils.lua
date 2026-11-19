local utils = {}
local pp = require('pretty-print')
for name, value in pairs(pp) do utils[name] = value end
local function bind(fn) return fn end
utils.bind = bind
return utils
