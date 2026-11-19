local geom = require "geom"
print(geom.area({ 3, 1, 2 }))
local ok = pcall(function() return geom.area({}) end)
