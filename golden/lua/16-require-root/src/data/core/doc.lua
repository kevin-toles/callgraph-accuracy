local common = require "core.common"

local Doc = {}

function Doc.line(n)
  return common.clamp(n, 1, 10)
end

return Doc
