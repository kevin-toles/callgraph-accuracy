local M = {}

function M.trim(s)
  return (s:gsub("^%s+", ""))
end

function M.clean(s)
  return M.trim(s)
end

return M
