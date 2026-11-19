local M = {}

local visit

local function walk(node)
  return visit(node.child)
end

function visit(node)
  if node then
    return walk(node)
  end
  return nil
end

local is_leaf
is_leaf = function(node)
  return node.child == nil
end

function M.run(tree)
  local function inner(n)
    return is_leaf(n)
  end
  return visit(tree), inner(tree)
end

return M
