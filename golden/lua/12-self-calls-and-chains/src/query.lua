local Q = {}

function Q.new()
  return setmetatable({ parts = {} }, { __index = Q })
end

function Q:where(cond)
  table.insert(self.parts, cond)
  return self
end

function Q:build()
  self:validate()
  return table.concat(self.parts, " AND ")
end

function Q:validate()
  return #self.parts
end

function Q.example()
  return Q.new()
    :where("a = 1")
    :where("b = 2")
    :build()
end

return Q
