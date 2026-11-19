local base = require "base"

function base.shout()
  return string.upper(base.hello())
end

base.whisper = function()
  return string.lower(base.hello())
end

return true
