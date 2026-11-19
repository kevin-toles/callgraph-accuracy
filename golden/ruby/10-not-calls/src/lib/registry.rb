class Registry
  def initialize
  end

  def check(value)
    return nil unless defined?(Registry)
    kind = :symbol
    list = [value, kind]
    opts = { key: value }
    store(list, opts)
  end

  def store(list, opts)
    "#{list}#{opts}"
  end
end
