local luvi = require('luvi')
local bundle = luvi.bundle
local pathJoin = require('luvi').path.join
local c = require('utils').color
local function start()
  bundle.readfile('x')
  pathJoin('a', 'b')
  c("err")
end
return start
