local utils = require "pl.utils"
local _M = {}
function _M.hosts()
  return utils.readlines("/etc/hosts")
end
return _M
