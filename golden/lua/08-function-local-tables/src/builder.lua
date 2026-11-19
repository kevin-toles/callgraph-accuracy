local M = {}

function M.build()
  local T = {}
  function T.step(x)
    return x
  end
  T.finish = function(x)
    return T.step(x)
  end
  return T.finish(1), T:step()
end

function M.other()
  local T = { size = 0 }
  function T:step()
    return self.size
  end
  return T:step()
end

return M
