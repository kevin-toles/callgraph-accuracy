local Counter = {}

function Counter.new(start)
  return setmetatable({ n = start }, { __index = Counter })
end

function Counter:incr()
  self.n = self.n + 1
  return self:value()
end

Counter.value = function(self)
  return self.n
end

Counter.reset = function(c)
  return Counter.new(0), Counter:value()
end

return Counter
