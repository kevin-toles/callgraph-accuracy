local common = {}

function common.clamp(n, lo, hi)
  return math.max(lo, math.min(hi, n))
end

function common.doc()
  return require "core.doc"
end

return common
