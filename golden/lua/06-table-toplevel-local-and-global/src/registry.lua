Registry = {}

local Cache = {}

function Cache.get(key)
  return Cache[key]
end

Cache.put = function(key, value)
  Cache[key] = value
end

function Registry.add(name)
  Cache.put(name, true)
  return Cache.get(name)
end

function Registry:count()
  return self.add("x")
end

return true
