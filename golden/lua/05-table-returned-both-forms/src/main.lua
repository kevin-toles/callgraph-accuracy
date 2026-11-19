local Counter = require "counter"
local c = Counter.new(1)
c:incr()
Counter.reset(c)
Counter:incr()
