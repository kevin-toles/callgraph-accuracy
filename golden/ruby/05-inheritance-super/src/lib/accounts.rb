class User
  def initialize(name)
    @name = name
  end

  def greet(other)
    other
  end
end

class Admin < User
  def initialize(name, level)
    super(name)
    @level = level
    grant(level)
  end

  def grant(level)
    greet(level)
    self.greet(level)
  end
end

class Guest < User
  def initialize
    super
  end
end
